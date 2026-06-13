import UIKit
import Flutter
import flutter_local_notifications
import PushKit
import UserNotifications
import CallKit
import AVFoundation
import FirebaseMessaging

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate {

    var voipRegistry: PKPushRegistry?
    var callChannel: FlutterMethodChannel?
    var currentCallUUID: String?
    var cachedVoipTokenString: String?
    var pendingAnsweredCallUUID: String?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        GeneratedPluginRegistrant.register(with: self)

        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

        // ==========================================
        // FLUTTER METHOD CHANNEL
        // ==========================================
        callChannel = FlutterMethodChannel(
            name: "com.getgabs/calls",
            binaryMessenger: controller.binaryMessenger
        )
        
        // ✅ CallManager ko apDelegate reference do
        CallManager.shared.appDelegate = self
        
        callChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
                
            case "endNativeCall":
                if let args = call.arguments as? [String: Any],
                   let uuidStr = args["uuid"] as? String,
                   let uuid = UUID(uuidString: uuidStr) {
                    CallManager.shared.endCallProgrammatically(uuid: uuid)
                    result(true)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "UUID missing", details: nil))
                }
                
            case "setupAudioSession":
                // Flutter WebRTC connect hone ke baad audio enable karo
                CallManager.shared.setupAudioSession()
                result(nil)
                
            case "getVoipTokenForcefully":
                if let cachedToken = self?.cachedVoipTokenString {
                    self?.callChannel?.invokeMethod("onVoipTokenReceived", arguments: cachedToken)
                } else {
                    self?.retriggerVoipRegistration()
                }
                result(nil)
                
            case "checkPendingAnsweredCall":
                if let pendingUuid = self?.pendingAnsweredCallUUID {
                    print("🚀 Sending pending answered UUID to Flutter: \(pendingUuid)")
                    result(["uuid": pendingUuid])
                    self?.pendingAnsweredCallUUID = nil
                } else {
                    result(nil)
                }

            // DEBUG: allow triggering an incoming call locally from Flutter
            case "simulateIncomingCall":
                if let args = call.arguments as? [String: Any] {
                    let uuidStr = (args["uuid"] as? String) ?? UUID().uuidString
                    let callerName = (args["callerName"] as? String) ?? "Sim Caller"
                    let callerNumber = (args["callerNumber"] as? String) ?? "0000000000"
                    let rawUuid = uuidStr.lowercased()
                    if let uuid = UUID(uuidString: rawUuid) {
                        print("🧪 simulateIncomingCall invoked — \(rawUuid)")
                        CallManager.shared.reportIncomingCall(uuid: uuid, callerName: callerName, callerNumber: callerNumber)
                        result(["status": "reported", "uuid": rawUuid])
                    } else {
                        print("❌ simulateIncomingCall invalid uuid: \(rawUuid)")
                        result(FlutterError(code: "INVALID_UUID", message: "Invalid UUID", details: nil))
                    }
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Arguments required", details: nil))
                }
                
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // ==========================================
        // FLUTTER LOCAL NOTIFICATIONS
        // ==========================================
        FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
            GeneratedPluginRegistrant.register(with: registry)
        }

        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
        }

        application.registerForRemoteNotifications()

        // ==========================================
        // PUSHKIT SETUP (VoIP)
        // ==========================================
        voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
        voipRegistry?.delegate = self
        voipRegistry?.desiredPushTypes = [.voIP]

        // Call end observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNativeCallEnd(_:)),
            name: NSNotification.Name("CALL_ENDED_NATIVE"),
            object: nil
        )

        // Call answer observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNativeCallAnswered(_:)),
            name: NSNotification.Name("CALL_ANSWERED_NATIVE"),
            object: nil
        )

        print("✅ AppDelegate initialized — Native CallKit mode")

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func retriggerVoipRegistration() {
        voipRegistry = nil
        voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
        voipRegistry?.delegate = self
        voipRegistry?.desiredPushTypes = [.voIP]
    }

    // MARK: - VOIP TOKEN RECEIVED
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        print("📲 VoIP Token received: \(token)")
        self.cachedVoipTokenString = token
        callChannel?.invokeMethod("onVoipTokenReceived", arguments: token)
    }

    override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        print("❌ VoIP Token Invalidated")
        self.cachedVoipTokenString = nil
        callChannel?.invokeMethod("onVoipTokenInvalid", arguments: nil)
    }

    // MARK: - INCOMING VOIP PUSH
    // ✅ FIX: Sirf native CallKit dikhao — flutter_callkit_incoming nahi
    // Ye VoIP push se trigger hota hai (app killed/background dono mein)
    func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        print("🔥 VoIP PUSH RECEIVED")

        let data = payload.dictionaryPayload
        print("📦 Payload: \(data)")

        // ✅ UUID handle karo
        let rawUuidString = (data["uuid"] as? String ?? UUID().uuidString).lowercased()
        let callerName = data["callerName"] as? String ?? "Incoming Call"
        let callerNumber = data["callerNumber"] as? String ?? ""

        guard let uuid = UUID(uuidString: rawUuidString) else {
            print("❌ Invalid UUID: \(rawUuidString)")
            // ✅ Apple requirement: MUST call completion and show CallKit
            // Agar valid UUID nahi hai, ek naya UUID banao
            let fallbackUUID = UUID()
            CallManager.shared.reportIncomingCall(
                uuid: fallbackUUID,
                callerName: callerName,
                callerNumber: callerNumber
            )
            completion()
            return
        }

        // Duplicate push guard
        if let existing = self.currentCallUUID, existing == rawUuidString {
            print("⚠️ Duplicate VoIP push ignored: \(rawUuidString)")
            completion()
            return
        }

        self.currentCallUUID = rawUuidString

        // ✅ KEY FIX: Native CXProvider se CallKit dikhao
        // flutter_callkit_incoming se nahi — warna double screen aata tha
        CallManager.shared.reportIncomingCall(
            uuid: uuid,
            callerName: callerName,
            callerNumber: callerNumber
        )

        // ✅ Apple ka strict requirement — completion() zaroor call karo
        completion()
        print("✅ VoIP push handled — native CallKit shown")

        // Flutter ko async notify karo (agar awake ho)
        DispatchQueue.main.async { [weak self] in
            self?.callChannel?.invokeMethod(
                "onIncomingVoipCall",
                arguments: [
                    "uuid": rawUuidString,
                    "callerName": callerName,
                    "callerNumber": callerNumber
                ]
            )
        }
    }

    // MARK: - CALL END OBSERVER
    @objc private func handleNativeCallEnd(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let uuidStr = userInfo["uuid"] as? String else { return }
        
        print("🧹 Call ended cleanup: \(uuidStr)")
        
        if self.currentCallUUID == uuidStr.lowercased() {
            self.currentCallUUID = nil
        }
        callChannel?.invokeMethod("onCallEndedNatively", arguments: ["uuid": uuidStr.lowercased()])
    }

    // MARK: - CALL ANSWER OBSERVER
    @objc private func handleNativeCallAnswered(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let uuidStr = userInfo["uuid"] as? String else { return }
        
        let cleanUuid = uuidStr.lowercased()
        print("📲 Call answered: \(cleanUuid)")

        if let channel = callChannel {
            channel.invokeMethod("onNativeCallAnswered", arguments: ["uuid": cleanUuid])
            print("✅ Flutter notified via onNativeCallAnswered")
        } else {
            // Flutter not ready (killed state) — cache karo
            print("⏳ Flutter not ready — caching: \(cleanUuid)")
            self.pendingAnsweredCallUUID = cleanUuid
        }
    }
}