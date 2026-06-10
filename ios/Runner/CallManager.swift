import Foundation
import CallKit
import UIKit
import AVFoundation

@objc public class CallManager: NSObject, CXProviderDelegate {

    @objc public static let shared = CallManager()

    private let provider: CXProvider
    private let callController = CXCallController()
    private var activeCalls: [UUID: String] = [:]
    // Background task id for answering in background
    private var answerBackgroundTask: UIBackgroundTaskIdentifier = .invalid

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

    // MARK: - ANSWER CALL (FIXED LIFECYCLE METHOD)
    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("📞 Call Answered in Native CallManager")
        
        // ⚠️ Fulfill immediately so OS unlocks audio session processing
        action.fulfill()
        // Begin a background task so iOS gives us time to finish setup while
        // the app is still backgrounded. We'll end it shortly after work completes.
        self.answerBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: "AnswerCall") {
            // expiration handler: ensure task is ended
            UIApplication.shared.endBackgroundTask(self.answerBackgroundTask)
            self.answerBackgroundTask = .invalid
        }

        // Small delay to let Flutter wake up completely from background memory loop
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.setupAudioSession()

            // Notify Flutter via accurate matching method string
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                NotificationCenter.default.post(
                    name: NSNotification.Name("CALL_ANSWERED_NATIVE"),
                    object: nil,
                    userInfo: ["uuid": action.callUUID.uuidString.lowercased()]
                )
                print("✅ Flutter notified via channel event: onNativeCallAnswered")
            }

            DispatchQueue.global(qos: .userInitiated).async {
                print("🚀 Native thread pool: Ready for WebRTC connection initialization")
            }

            // End the background task after a short delay to allow Flutter/native work to start
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if self.answerBackgroundTask != .invalid {
                    UIApplication.shared.endBackgroundTask(self.answerBackgroundTask)
                    self.answerBackgroundTask = .invalid
                    print("✅ Answer background task ended")
                }
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
        print("🔊 Audio Session Activated")
    }

    // MARK: - AUDIO SETUP
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.allowBluetooth]
            )
            try session.setActive(true)
            print("🔊 Audio ready")
        } catch {
            print("❌ Audio setup error: \(error)")
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
