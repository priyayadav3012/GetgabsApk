import Foundation
import CallKit
import UIKit
import AVFoundation
import WebRTC

// ✅ FINAL: Pure native iOS CallKit — flutter_callkit_incoming bypass
// Ye file poori calling lifecycle handle karti hai iOS pe

@objc public class CallManager: NSObject, CXProviderDelegate {

    @objc public static let shared = CallManager()

    private let provider: CXProvider
    private let callController = CXCallController()
    private var activeCalls: [UUID: String] = [:]
    
    // Flutter ko callback dene ke liye
    weak var appDelegate: AppDelegate?

    @objc public var hasActiveCall: Bool {
        return !activeCalls.isEmpty
    }

    override init() {
        let config = CXProviderConfiguration(localizedName: "GetGabs")
        config.supportsVideo = false
        config.maximumCallGroups = 1
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes = [.phoneNumber]
        config.includesCallsInRecents = true
        config.ringtoneSound = "ringtone.caf"

        if let image = UIImage(named: "IconMask") {
            config.iconTemplateImageData = image.pngData()
        }

        self.provider = CXProvider(configuration: config)
        super.init()
        self.provider.setDelegate(self, queue: DispatchQueue.main)

        // ✅ WebRTC manual audio — CXProvider delegate activate karega
        let rtcAudioSession = RTCAudioSession.sharedInstance()
        rtcAudioSession.useManualAudio = true
        rtcAudioSession.isAudioEnabled = false
        
        print("✅ CallManager initialized with native CXProvider")
    }

    // MARK: - INCOMING CALL
    @objc public func reportIncomingCall(uuid: UUID, callerName: String, callerNumber: String) {
        print("📨 reportIncomingCall called — uuid: \(uuid.uuidString), caller: \(callerName), number: \(callerNumber)")

        // Pehle se active call hai toh end karo
        if !activeCalls.isEmpty {
            print("⚠️ There is an existing active call(s): \(activeCalls.keys.map { $0.uuidString }) — ending them before reporting new call")
            for oldUuid in activeCalls.keys {
                provider.reportCall(with: oldUuid, endedAt: Date(), reason: .failed)
            }
            activeCalls.removeAll()
        }

        let update = CXCallUpdate()
        let handle = callerNumber.isEmpty ? callerName : callerNumber
        update.remoteHandle = CXHandle(type: .phoneNumber, value: handle)
        update.localizedCallerName = callerName.isEmpty ? callerNumber : callerName
        update.hasVideo = false
        update.supportsHolding = false
        update.supportsDTMF = false
        update.supportsGrouping = false
        update.supportsUngrouping = false

        // Ensure CallKit reporting happens on main thread
        DispatchQueue.main.async { [weak self] in
            print("🔁 Reporting new incoming call to CXProvider on main thread")
            self?.provider.reportNewIncomingCall(with: uuid, update: update) { error in
                if let error = error {
                    print("❌ CallKit incoming error: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self?.appDelegate?.callChannel?.invokeMethod(
                            "onCallKitError",
                            arguments: ["error": error.localizedDescription]
                        )
                    }
                    return
                }
                self?.activeCalls[uuid] = handle
                print("✅ Native CallKit UI shown for: \(callerName) (\(callerNumber)) — activeCalls now: \(self?.activeCalls.keys.map { $0.uuidString } ?? [])")
            }
        }
    }

    // MARK: - ANSWER CALL
    public func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        print("📞 User answered call — UUID: \(action.callUUID)")
        
        // ✅ Immediately fulfill — OS audio unlock ke liye zaroori
        action.fulfill()

        setupAudioSession()

        DispatchQueue.main.async { [weak self] in
            let uuidStr = action.callUUID.uuidString.lowercased()
            
            if let channel = self?.appDelegate?.callChannel {
                channel.invokeMethod("onNativeCallAnswered", arguments: ["uuid": uuidStr])
                print("✅ Flutter notified: onNativeCallAnswered")
            } else {
                // Flutter abhi ready nahi — cache karo
                print("⏳ Flutter not ready — caching answered UUID: \(uuidStr)")
                self?.appDelegate?.pendingAnsweredCallUUID = uuidStr
            }
            
            NotificationCenter.default.post(
                name: NSNotification.Name("CALL_ANSWERED_NATIVE"),
                object: nil,
                userInfo: ["uuid": uuidStr]
            )
        }
    }

    // MARK: - END CALL
    public func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        print("📵 Call ended — UUID: \(action.callUUID)")
        
        let uuidStr = action.callUUID.uuidString.lowercased()
        activeCalls.removeValue(forKey: action.callUUID)
        action.fulfill()

        deactivateAudioSession()

        DispatchQueue.main.async { [weak self] in
            self?.appDelegate?.callChannel?.invokeMethod(
                "onCallEndedNatively",
                arguments: ["uuid": uuidStr]
            )
            NotificationCenter.default.post(
                name: NSNotification.Name("CALL_ENDED_NATIVE"),
                object: nil,
                userInfo: ["uuid": uuidStr]
            )
        }
        
        if appDelegate?.currentCallUUID == uuidStr {
            appDelegate?.currentCallUUID = nil
        }
    }

    // MARK: - AUDIO ACTIVATED (CXProvider callback — awaaz ke liye most important)
    public func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        print("🔊 Audio Session Activated by CXProvider")
        let rtcSession = RTCAudioSession.sharedInstance()
        rtcSession.audioSessionDidActivate(audioSession)
        // ✅ YE LINE awaaz aane ke liye zaroori — pehle ye missing thi
        rtcSession.isAudioEnabled = true
        print("✅ WebRTC audio ENABLED")
    }

    // MARK: - AUDIO DEACTIVATED
    public func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        print("🔇 Audio Session Deactivated")
        let rtcSession = RTCAudioSession.sharedInstance()
        rtcSession.audioSessionDidDeactivate(audioSession)
        rtcSession.isAudioEnabled = false
    }

    // MARK: - AUDIO SETUP
    @objc public func setupAudioSession() {
        let rtcAudioSession = RTCAudioSession.sharedInstance()
        rtcAudioSession.lockForConfiguration()
        defer { rtcAudioSession.unlockForConfiguration() }
        
        do {
            let configuration = RTCAudioSessionConfiguration.webRTC()
            configuration.category = AVAudioSession.Category.playAndRecord.rawValue
            configuration.mode = AVAudioSession.Mode.voiceChat.rawValue
            configuration.categoryOptions = [.allowBluetooth, .allowBluetoothA2DP]
            
            try rtcAudioSession.setConfiguration(configuration)
            rtcAudioSession.isAudioEnabled = true
            print("🔊 Audio session manually configured + enabled")
        } catch {
            print("❌ Audio session error: \(error)")
        }
    }

    @objc public func deactivateAudioSession() {
        let rtcAudioSession = RTCAudioSession.sharedInstance()
        rtcAudioSession.isAudioEnabled = false
        
        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        } catch {
            print("❌ Deactivate error: \(error)")
        }
    }

    // MARK: - PROVIDER RESET
    public func providerDidReset(_ provider: CXProvider) {
        activeCalls.removeAll()
        deactivateAudioSession()
        print("♻️ CXProvider reset")
    }

    // MARK: - PROGRAMMATIC END CALL (Flutter se call hota hai)
    @objc public func endCallProgrammatically(uuid: UUID) {
        let action = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: action)
        callController.request(transaction) { error in
            if let error = error {
                print("❌ Programmatic end failed: \(error)")
                self.activeCalls.removeValue(forKey: uuid)
                self.deactivateAudioSession()
            } else {
                print("✅ Call ended programmatically")
            }
        }
    }
    
    @objc public var activeCallUUID: UUID? {
        return activeCalls.keys.first
    }
}