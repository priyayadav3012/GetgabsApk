import Foundation
import CallKit
import AVFoundation

class CallManager: NSObject, CXProviderDelegate {
    
    static let shared = CallManager()
    
    private let provider: CXProvider
    private let callController = CXCallController()
    
    override init() {
        let providerConfiguration = CXProviderConfiguration(localizedName: "GetGabs")
        providerConfiguration.supportsVideo = false
        providerConfiguration.maximumCallGroups = 1
        providerConfiguration.maximumCallsPerCallGroup = 1
        providerConfiguration.supportedHandleTypes = [.generic]
        
        // Ringtone customization (Optional)
        // providerConfiguration.ringtoneSound = "ringtone.caf"
        
        self.provider = CXProvider(configuration: providerConfiguration)
        
        super.init()
        self.provider.setDelegate(self, queue: nil)
    }
    
    // MARK: - Public Actions
    
    func reportIncomingCall(uuid: UUID, handle: String) {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: handle)
        update.hasVideo = false // Change to true if it's a video call
        
        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error = error {
                print("❌ [CallKit] Error reporting incoming call: \(error.localizedDescription)")
            } else {
                print("✅ [CallKit] Incoming call reported successfully for UUID: \(uuid.uuidString)")
            }
        }
    }
    
    func endCallProgrammatically(uuid: UUID) {
        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)
        
        callController.request(transaction) { error in
            if let error = error {
                print("❌ [CallKit] Error requesting end call transaction: \(error.localizedDescription)")
            } else {
                print("✅ [CallKit] End call transaction requested successfully.")
            }
        }
    }
    
    // MARK: - CXProviderDelegate Callbacks
    
    func providerDidReset(_ provider: CXProvider) {
        print("🔄 [CallKit] Provider Reset. Cleaning up all audio sessions.")
        NotificationCenter.default.post(name: NSNotification.Name("CALL_ENDED_NATIVE"), object: nil, userInfo: ["uuid": ""])
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("📲 [CallKit] User Answered Call from UI/LockScreen.")
        
        // Notify AppDelegate/Flutter immediately about the action
        NotificationCenter.default.post(
            name: NSNotification.Name("CALL_ANSWERED_NATIVE"),
            object: nil,
            userInfo: ["uuid": action.callUUID.uuidString]
        )
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("🛑 [CallKit] User Ended Call / Rejected Call from UI.")
        
        NotificationCenter.default.post(
            name: NSNotification.Name("CALL_ENDED_NATIVE"),
            object: nil,
            userInfo: ["uuid": action.callUUID.uuidString]
        )
        
        action.fulfill()
    }
    
    // MARK: - 🎵 Critical AVAudioSession Management
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print("🎵 [CallKit] didActivate audioSession — configuring for WebRTC/VoIP.")
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ [CallKit] AVAudioSession activated.")
        } catch {
            print("❌ [CallKit] AVAudioSession activate error: \(error.localizedDescription)")
        }
        // Notify Flutter so WebRTC can sync with the activated audio session.
        NotificationCenter.default.post(name: NSNotification.Name("CALLKIT_AUDIO_SESSION_ACTIVATED"), object: nil)
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("🔇 [CallKit] didDeactivate audioSession.")
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            print("✅ [CallKit] AVAudioSession deactivated.")
        } catch {
            print("❌ [CallKit] AVAudioSession deactivate error: \(error.localizedDescription)")
        }
        NotificationCenter.default.post(name: NSNotification.Name("CALLKIT_AUDIO_SESSION_DEACTIVATED"), object: nil)
    }
}