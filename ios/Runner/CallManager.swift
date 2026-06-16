import Foundation
import CallKit
import UIKit
import AVFoundation
import WebRTC

@objc public class CallManager: NSObject, CXProviderDelegate {

    @objc public static let shared = CallManager()

    private let provider: CXProvider
    private let callController = CXCallController()
    private var activeCalls: [UUID: String] = [:]
    private var _muteRequestedByApp = false
    // Tracks whether CallKit has granted the audio session (didActivate fired).
    // setSpeaker and setAudioEnabled must only act after this is true.
    private var _audioSessionActive = false
    // Speaker change requested before didActivate — applied once session is active.
    private var _pendingSpeakerEnabled: Bool? = nil

    override init() {
        let config = CXProviderConfiguration(localizedName: "GetGabs")
        config.supportsVideo = false
        config.maximumCallGroups = 1
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes = [.generic]
        config.includesCallsInRecents = false
        config.ringtoneSound = "ringtone.caf"

        if let image = UIImage(named: "IconMask") {
            config.iconTemplateImageData = image.pngData()
        }

        self.provider = CXProvider(configuration: config)
        super.init()
        self.provider.setDelegate(self, queue: nil)

        let rtcAudioSession = RTCAudioSession.sharedInstance()
        rtcAudioSession.useManualAudio = true
        rtcAudioSession.isAudioEnabled = false

        // Forward audio route changes (speaker ↔ earpiece) to Flutter so the app
        // UI stays in sync when the user changes routing from the native CallKit screen.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    // MARK: - INCOMING CALL
    @objc public func reportIncomingCall(uuid: UUID, handle: String) {
        if !activeCalls.isEmpty {
            for oldUuid in activeCalls.keys {
                provider.reportCall(with: oldUuid, endedAt: Date(), reason: .failed)
            }
            activeCalls.removeAll()
        }

        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: handle)
        update.localizedCallerName = handle
        update.hasVideo = false
        update.supportsHolding = false
        update.supportsDTMF = false
        update.supportsGrouping = false
        update.supportsUngrouping = false

        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error = error {
                print("❌ CallKit incoming error: \(error)")
                return
            }
            print("✅ CallKit UI shown")
            self.activeCalls[uuid] = handle
        }
    }

    // MARK: - ANSWER CALL
    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("📞 Call Answered in Native CallManager")

        // Fulfill first so OS schedules audio session activation.
        // Audio session configuration happens in didActivate — NOT here — to ensure
        // RTCAudioSession is configured only after the OS grants the audio session.
        action.fulfill()

        let uuid = action.callUUID.uuidString.lowercased()
        tryNotifyFlutter(uuid: uuid, attempt: 0)
    }

    private func tryNotifyFlutter(uuid: String, attempt: Int) {
        guard attempt < 20 else {
            DispatchQueue.main.async {
                if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                    print("⏳ Flutter not ready after 10s — caching UUID: \(uuid)")
                    appDelegate.pendingAnsweredCallUUID = uuid
                }
            }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
                self.tryNotifyFlutter(uuid: uuid, attempt: attempt + 1)
                return
            }
            if let channel = appDelegate.callChannel {
                channel.invokeMethod("onNativeCallAnswered", arguments: ["uuid": uuid])
                print("✅ Flutter notified: onNativeCallAnswered (attempt \(attempt + 1))")
            } else {
                print("⏳ Flutter channel not ready (attempt \(attempt + 1)) — retrying…")
                self.tryNotifyFlutter(uuid: uuid, attempt: attempt + 1)
            }
        }
    }

    // MARK: - MUTE CALL
    public func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        print("🔇 CallKit mute toggled: \(action.isMuted)")
        action.fulfill()
        if _muteRequestedByApp {
            _muteRequestedByApp = false
            return
        }
        DispatchQueue.main.async {
            if let channel = (UIApplication.shared.delegate as? AppDelegate)?.callChannel {
                channel.invokeMethod("onCallMuteChanged", arguments: ["muted": action.isMuted])
            }
        }
    }

    @objc public func setMuted(_ muted: Bool) {
        guard !activeCalls.isEmpty, let uuid = activeCalls.keys.first else { return }
        _muteRequestedByApp = true
        let action = CXSetMutedCallAction(call: uuid, muted: muted)
        let transaction = CXTransaction(action: action)
        callController.request(transaction) { [weak self] error in
            if let error = error {
                print("❌ setMuted failed: \(error)")
                self?._muteRequestedByApp = false
            }
        }
    }

    // MARK: - AUDIO ENABLE
    // Called from Flutter via setAudioEnabled method channel. Only used on Android
    // or when flutter_callkit_incoming owns the CXProvider (not native CallManager).
    // On iOS with native CallManager, audio is enabled exclusively in didActivate.
    @objc public func setAudioEnabled(_ enabled: Bool) {
        let rtcSession = RTCAudioSession.sharedInstance()
        rtcSession.isAudioEnabled = enabled
        print("🔊 RTCAudioSession.isAudioEnabled = \(enabled)")
    }

    // MARK: - SPEAKER
    // Public entry point: queues the request if the audio session isn't active yet.
    @objc public func setSpeaker(_ enabled: Bool) {
        guard _audioSessionActive else {
            _pendingSpeakerEnabled = enabled
            print("⏳ Speaker change queued — audio session not yet active")
            return
        }
        applySpeaker(enabled)
    }

    // Applies the speaker override. Only call when _audioSessionActive == true.
    // Uses AVAudioSession directly — NOT RTCAudioSession — because WebRTC's audio
    // unit is actively running at this point and RTCAudioSession's override goes
    // through its internal queue where it can be silently reverted by the unit.
    // overrideOutputAudioPort does not need the RTCAudioSession configuration lock.
    private func applySpeaker(_ enabled: Bool) {
        do {
            try AVAudioSession.sharedInstance().overrideOutputAudioPort(enabled ? .speaker : .none)
            print("🔊 Speaker \(enabled ? "ON" : "OFF")")
        } catch {
            print("❌ Speaker toggle error: \(error)")
        }
    }

    // MARK: - ROUTE CHANGE — notify Flutter when native speaker state changes
    @objc private func handleAudioRouteChange(_ notification: Notification) {
        guard _audioSessionActive else { return }
        let isSpeaker = AVAudioSession.sharedInstance().currentRoute.outputs.contains {
            $0.portType == .builtInSpeaker
        }
        DispatchQueue.main.async {
            if let channel = (UIApplication.shared.delegate as? AppDelegate)?.callChannel {
                channel.invokeMethod("onSpeakerChanged", arguments: ["enabled": isSpeaker])
            }
        }
    }

    // MARK: - END CALL
    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("📵 Call Ended")
        _audioSessionActive = false
        _pendingSpeakerEnabled = nil
        activeCalls.removeValue(forKey: action.callUUID)

        NotificationCenter.default.post(
            name: NSNotification.Name("CALL_ENDED_NATIVE"),
            object: nil,
            userInfo: ["uuid": action.callUUID.uuidString.lowercased()]
        )

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ Audio deactivate error: \(error)")
        }
        action.fulfill()
    }

    // MARK: - AUDIO ACTIVATED
    // This is the authoritative point to configure and enable RTCAudioSession.
    // Doing it earlier (e.g., in CXAnswerCallAction) races with the OS activation.
    public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print("🔊 Audio Session Activated")
        _audioSessionActive = true
        let rtcSession = RTCAudioSession.sharedInstance()
        setupAudioSession()
        rtcSession.audioSessionDidActivate(audioSession)
        rtcSession.isAudioEnabled = true
        // Apply any speaker change that arrived before the session was active.
        if let pending = _pendingSpeakerEnabled {
            _pendingSpeakerEnabled = nil
            applySpeaker(pending)
        }
    }

    // MARK: - AUDIO DEACTIVATED
    public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("🔇 Audio Session Deactivated")
        _audioSessionActive = false
        let rtcSession = RTCAudioSession.sharedInstance()
        rtcSession.audioSessionDidDeactivate(audioSession)
        rtcSession.isAudioEnabled = false
    }

    // MARK: - AUDIO SETUP
    private func setupAudioSession() {
        let rtcAudioSession = RTCAudioSession.sharedInstance()
        rtcAudioSession.lockForConfiguration()
        defer {
            rtcAudioSession.unlockForConfiguration()
        }

        do {
            let configuration = RTCAudioSessionConfiguration.webRTC()
            configuration.category = AVAudioSession.Category.playAndRecord.rawValue
            configuration.mode = AVAudioSession.Mode.voiceChat.rawValue
            configuration.categoryOptions = [.allowBluetooth, .allowBluetoothA2DP]

            try rtcAudioSession.setConfiguration(configuration)
            print("🔊 RTCAudioSession configured successfully")
        } catch {
            print("❌ RTCAudioSession configuration error: \(error)")
        }
    }

    // MARK: - PROVIDER RESET
    public func providerDidReset(_ provider: CXProvider) {
        _audioSessionActive = false
        _pendingSpeakerEnabled = nil
        activeCalls.removeAll()
        print("♻️ Provider reset")
    }

    // MARK: - PROGRAMMATIC END CALL
    @objc public func endCallProgrammatically(uuid: UUID) {
        let action = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: action)

        callController.request(transaction) { error in
            if let error = error {
                print("❌ End call failed: \(error)")
            } else {
                print("✅ Call ended programmatically")
            }
        }
    }
}
