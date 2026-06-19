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

        // Configure WebRTC to use manual audio management and start disabled
        let rtcAudioSession = RTCAudioSession.sharedInstance()
        rtcAudioSession.useManualAudio = true
        rtcAudioSession.isAudioEnabled = false
    }

    // MARK: - INCOMING CALL
    @objc public func reportIncomingCall(uuid: UUID, handle: String) {
        // End previous calls if any active
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

    // #changedWithJClaude — Bug 1: new helper; retries every 0.5 s up to 20× then caches UUID.
    private func tryNotifyFlutter(uuid: String, attempt: Int) {
        guard attempt < 20 else {
            // Flutter never became ready — cache so checkPendingAnsweredCall() retrieves it
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

    // MARK: - END CALL
    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("📵 Call Ended")
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
    public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print("🔊 Audio Session Activated by CallKit")
        // Configure WebRTC audio session HERE — after CallKit has activated the session.
        // Calling setConfiguration before activation (e.g. in the answer action) races
        // with the system and can silently fail or produce distorted audio.
        setupAudioSession()
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
