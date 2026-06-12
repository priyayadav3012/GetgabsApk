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
        config.ringtoneSound = "ringtone.caf"

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

    // MARK: - ANSWER CALL (FIXED LIFECYCLE METHOD)
    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("📞 Call Answered in Native CallManager")
        
        // ⚠️ Fulfill immediately so OS unlocks audio session processing
        action.fulfill()

        // Small delay to let Flutter wake up completely from background memory loop
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.setupAudioSession()

            // Notify Flutter via accurate matching method string
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                appDelegate.callChannel?.invokeMethod(
                    "onNativeCallAnswered",
                    arguments: [
                        "uuid": action.callUUID.uuidString.lowercased()
                    ]
                )
                print("✅ Flutter notified via channel event: onNativeCallAnswered")
            }

            DispatchQueue.global(qos: .userInitiated).async {
                print("🚀 Native thread pool: Ready for WebRTC connection initialization")
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
