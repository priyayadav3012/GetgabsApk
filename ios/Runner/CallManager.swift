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
    // Tracks UUIDs that have been answered (not just ringing).
    // Used to prevent a second VoIP push from terminating an active call.
    private var answeredCallUUIDs: Set<UUID> = []

    override init() {
        let config = CXProviderConfiguration(localizedName: "GetGabs")
        config.supportsVideo = false
        config.maximumCallGroups = 1
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes = [.generic]
        config.includesCallsInRecents = false
        // nil = use iOS system default ringtone.
        // "ringtone.caf" was set here but the file was never added to the Xcode
        // bundle, causing CallKit to show an incoming call UI with no audio.
        // To use a custom ringtone: add the .caf file to the Xcode project's
        // Copy Bundle Resources phase and restore: config.ringtoneSound = "ringtone.caf"
        config.ringtoneSound = nil

        if let image = UIImage(named: "IconMask") {
            config.iconTemplateImageData = image.pngData()
        }

        self.provider = CXProvider(configuration: config)
        super.init()
        self.provider.setDelegate(self, queue: nil)

        // Configure WebRTC audio BEFORE any call so the configuration is already
        // in place when CallKit activates the session. Calling setConfiguration
        // inside didActivate changes the AVAudioSession category mid-handoff,
        // which makes iOS treat our app as interrupting TelephonyUtilities —
        // that interruption is rejected and audio never starts.
        let rtcAudioSession = RTCAudioSession.sharedInstance()
        rtcAudioSession.useManualAudio = true
        rtcAudioSession.isAudioEnabled = false
        configureWebRTCAudio()
    }

    // MARK: - INCOMING CALL
    @objc public func reportIncomingCall(uuid: UUID, handle: String) {
        // If any call in activeCalls has already been answered, a second VoIP push
        // must not interrupt it. Return immediately — do NOT show a new CallKit UI
        // and do NOT terminate the in-progress call.
        let hasAnsweredCall = activeCalls.keys.contains { answeredCallUUIDs.contains($0) }
        if hasAnsweredCall {
            print("⚠️ reportIncomingCall: call already answered — ignoring duplicate push for \(uuid.uuidString)")
            return
        }

        // Only terminate calls that are still ringing (unanswered).
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

    // #changedWithJClaude — Bug 1: replaced single 0.3s attempt with 20-retry loop so
    // killed-state Flutter channel has time to initialise; sets pendingAnsweredCallUUID as fallback.
    // MARK: - ANSWER CALL
    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("📞 Call Answered in Native CallManager")

        // Fulfill first — this tells CallKit the answer was accepted and triggers
        // provider(_:didActivate:) asynchronously.  Audio session configuration
        // is deferred to didActivate so it runs after the system has activated the
        // session (see H-2 fix).
        action.fulfill()

        // Mark this UUID as answered so reportIncomingCall can guard against a
        // second VoIP push arriving while this call is active.
        answeredCallUUIDs.insert(action.callUUID)

        let uuid = action.callUUID.uuidString.lowercased()

        // Post CALL_ANSWERED_NATIVE so AppDelegate.handleNativeCallAnswered can cache
        // the UUID in pendingAnsweredCallUUID if the Flutter engine isn't ready yet.
        // tryNotifyFlutter retries for up to 10 s; the AppDelegate observer is the
        // last-resort cache path if all 20 retries are exhausted before Dart starts.
        NotificationCenter.default.post(
            name: NSNotification.Name("CALL_ANSWERED_NATIVE"),
            object: nil,
            userInfo: ["uuid": uuid]
        )

        // Retry loop: Flutter engine may not be ready yet (especially in killed state).
        // We retry every 0.5s up to 20 times (10s total).
        // If all retries fail the UUID is cached so checkPendingAnsweredCall() can pick it up.
        tryNotifyFlutter(uuid: uuid, attempt: 0)
    }

    // Retries every 0.5 s up to 20×.
    // handleNativeCallAnswered always caches the UUID in pendingAnsweredCallUUID.
    // When we successfully invoke Flutter we clear the cache so checkPendingAnsweredCall
    // skips it (preventing double-fire). If checkPendingAnsweredCall fires first (killed
    // state), it clears the cache and we detect nil here and stop retrying.
    private func tryNotifyFlutter(uuid: String, attempt: Int) {
        guard attempt < 20 else {
            // All retries exhausted — pendingAnsweredCallUUID is still set so
            // checkPendingAnsweredCall() will pick it up on next Dart-side poll.
            print("⏳ All retries exhausted — checkPendingAnsweredCall will handle UUID: \(uuid)")
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
                self.tryNotifyFlutter(uuid: uuid, attempt: attempt + 1)
                return
            }
            // If cache is nil, checkPendingAnsweredCall already handled this call — stop.
            guard appDelegate.pendingAnsweredCallUUID != nil else {
                print("✅ UUID already handled by checkPendingAnsweredCall (attempt \(attempt + 1)) — stopping")
                return
            }
            if let channel = appDelegate.callChannel {
                // Claim the UUID before invoking to race-safely prevent checkPendingAnsweredCall
                appDelegate.pendingAnsweredCallUUID = nil
                channel.invokeMethod("onNativeCallAnswered", arguments: ["uuid": uuid])
                print("✅ Flutter notified: onNativeCallAnswered (attempt \(attempt + 1))")
            } else {
                print("⏳ Flutter channel not ready (attempt \(attempt + 1)) — retrying…")
                self.tryNotifyFlutter(uuid: uuid, attempt: attempt + 1)
            }
        }
    }

    // MARK: - END CALL
    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("📵 Call Ended")
        activeCalls.removeValue(forKey: action.callUUID)
        answeredCallUUIDs.remove(action.callUUID)

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
    public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print("🔊 Audio Session Activated by CallKit")
        // Only notify WebRTC that CallKit handed us the session — do NOT call
        // setConfiguration here. Reconfiguring the AVAudioSession category/mode
        // inside didActivate triggers an iOS-level "interruption" of
        // TelephonyUtilities (the CallKit audio owner), which is rejected and
        // silently kills the audio, causing the call to drop ~2 s after answering.
        let rtcSession = RTCAudioSession.sharedInstance()
        rtcSession.audioSessionDidActivate(audioSession)
        rtcSession.isAudioEnabled = true
    }

    // MARK: - AUDIO DEACTIVATED
    public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("🔇 Audio Session Deactivated")
        let rtcSession = RTCAudioSession.sharedInstance()
        rtcSession.audioSessionDidDeactivate(audioSession)
        rtcSession.isAudioEnabled = false
    }

    // MARK: - AUDIO PRE-CONFIGURATION
    // Called once at init so WebRTC's desired category/mode is staged before
    // any call. This runs while no session is active, so iOS accepts the change
    // without conflict.
    private func configureWebRTCAudio() {
        let rtcAudioSession = RTCAudioSession.sharedInstance()
        rtcAudioSession.lockForConfiguration()
        defer { rtcAudioSession.unlockForConfiguration() }

        do {
            let configuration = RTCAudioSessionConfiguration.webRTC()
            configuration.category = AVAudioSession.Category.playAndRecord.rawValue
            configuration.mode = AVAudioSession.Mode.voiceChat.rawValue
            configuration.categoryOptions = [.allowBluetooth, .allowBluetoothA2DP]
            try rtcAudioSession.setConfiguration(configuration)
            print("🔊 RTCAudioSession pre-configured")
        } catch {
            print("❌ RTCAudioSession pre-config error: \(error)")
        }
    }

    // MARK: - PROVIDER RESET
    public func providerDidReset(_ provider: CXProvider) {
        // iOS resets the provider under memory pressure or after fatal CallKit
        // errors. Post CALL_ENDED_NATIVE for every active call so AppDelegate
        // clears isCallActive and Flutter receives the end signal — without this
        // isCallActive stays true forever and all future VoIP pushes are silently
        // discarded.
        for uuid in activeCalls.keys {
            NotificationCenter.default.post(
                name: NSNotification.Name("CALL_ENDED_NATIVE"),
                object: nil,
                userInfo: ["uuid": uuid.uuidString.lowercased()]
            )
        }
        activeCalls.removeAll()
        answeredCallUUIDs.removeAll()
        print("♻️ Provider reset")
    }

    // MARK: - MANUAL AUDIO SESSION ACTIVATION
    // Called when flutter_callkit_incoming wins the CXProvider race so
    // CallManager.provider(_:didActivate:) never fires. Replicates what
    // didActivate does: hand the active session to RTCAudioSession and
    // enable audio so getUserMedia() succeeds in answerCall().
    @objc public func activateAudioSession() {
        print("🔊 CallManager.activateAudioSession — enabling RTCAudioSession manually")
        let rtcSession = RTCAudioSession.sharedInstance()
        rtcSession.audioSessionDidActivate(AVAudioSession.sharedInstance())
        rtcSession.isAudioEnabled = true
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
