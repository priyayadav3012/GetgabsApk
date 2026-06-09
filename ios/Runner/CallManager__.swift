import Foundation
import CallKit
import AVFoundation

// 1. Added @objc and public so the AppDelegate.swift can see this class
@objc public class CallManager: NSObject {
    
    @objc public static let shared = CallManager()
    
    private let provider: CXProvider
    private let callController = CXCallController()
    private(set) var activeCalls = [UUID: String]()
    
    override init() {
        let configuration = CXProviderConfiguration()
        configuration.supportsVideo = true
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportedHandleTypes = [.generic, .phoneNumber]
        
        self.provider = CXProvider(configuration: configuration)
        super.init()
        self.provider.setDelegate(self, queue: nil)
    }
    
    // MARK: - Actions
    
    @objc public func reportIncomingCall(uuid: UUID, handle: String, hasVideo: Bool = false) {
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: handle)
        update.hasVideo = hasVideo
        
        provider.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error == nil {
                self.activeCalls[uuid] = handle
            }
        }
    }
}   

// MARK: - CXProviderDelegate
extension CallManager: CXProviderDelegate {
    
    func providerDidReset(_ provider: CXProvider) {
        activeCalls.removeAll()
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("User answered the call")
        
        // 2. TRIGGER FLUTTER DESIGN
        // This finds your AppDelegate and sends a signal to Flutter to show the "WhatsApp Screen"
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.callChannel?.invokeMethod("onAnswered", arguments: nil)
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [])
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("User ended the call")
        
        // 3. TELL FLUTTER CALL ENDED (Optional)
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.callChannel?.invokeMethod("onEnded", arguments: nil)
        }
        
        activeCalls.removeValue(forKey: action.callUUID)
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        // Your WebRTC engine should start here
        print("Audio session activated.")
    }
}