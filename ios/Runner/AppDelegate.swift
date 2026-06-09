import UIKit
import Flutter
import flutter_local_notifications
import PushKit
import UserNotifications
import CallKit
import AVFoundation

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate {

    var voipRegistry: PKPushRegistry?
    var callChannel: FlutterMethodChannel?
    var currentCallUUID: String?
    
    // 🔥 Variable to cache token if Flutter requests it late
    var cachedVoipTokenString: String?

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
        
        callChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            if call.method == "endNativeCall" {
                if let args = call.arguments as? [String: Any],
                   let uuidStr = args["uuid"] as? String,
                   let uuid = UUID(uuidString: uuidStr) {
                    CallManager.shared.endCallProgrammatically(uuid: uuid)
                    result(true)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "UUID missing", details: nil))
                }
            }
            // 🔥 NEW: Flutter handles force wake up token queries
            else if call.method == "getVoipTokenForcefully" {
                print("📡 Flutter requested token forcefully.")
                if let cachedToken = self?.cachedVoipTokenString {
                    print("🚀 Dispatching cached VoIP token instantly: \(cachedToken)")
                    self?.callChannel?.invokeMethod("onVoipTokenReceived", arguments: cachedToken)
                } else {
                    print("⏳ No cached token found, re-initializing push registry configurations...")
                    self?.retriggerVoipRegistration()
                }
                result(nil)
            } else {
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

        // ==========================================
        // PUSHKIT SETUP (VoIP Pushes)
        // ==========================================
        voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
        voipRegistry?.delegate = self
        voipRegistry?.desiredPushTypes = [.voIP]

        // 1. Native Call End Lifecycle Linker
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNativeCallEnd(_:)),
            name: NSNotification.Name("CALL_ENDED_NATIVE"),
            object: nil
        )

        // 2. NATIVE CALL ANSWER LIFECYCLE LINKER
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNativeCallAnswered(_:)),
            name: NSNotification.Name("CALL_ANSWERED_NATIVE"),
            object: nil
        )

        print("✅ PushKit and CallKit Event Listeners Initialized")

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // 🔥 Helper method to force re-register if token is totally empty
    private func retriggerVoipRegistration() {
        voipRegistry = nil
        voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
        voipRegistry?.delegate = self
        voipRegistry?.desiredPushTypes = [.voIP]
    }

    // MARK: - VOIP TOKEN RECEIVED
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        print("📲 VoIP Token: \(token)")
        
        // 🔥 Cache the token safely inside instance memory
        self.cachedVoipTokenString = token
        
        callChannel?.invokeMethod("onVoipTokenReceived", arguments: token)
    }

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        print("❌ VoIP Token Invalidated")
        self.cachedVoipTokenString = nil
        callChannel?.invokeMethod("onVoipTokenInvalid", arguments: nil)
    }

    // MARK: - INCOMING VOIP PUSH
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        print("🔥 VOIP PUSH RECEIVED IN APPDELEGATE")

        let data = payload.dictionaryPayload
        print("📦 Payload Data: \(data)")

        let rawUuidString = data["uuid"] as? String ?? UUID().uuidString
        let uuidString = rawUuidString.lowercased()
        let callerName = data["callerName"] as? String ?? "Incoming Call"

        guard let uuid = UUID(uuidString: uuidString) else {
            print("❌ Invalid UUID string received: \(uuidString)")
            completion()
            return
        }

        self.currentCallUUID = uuidString
        print("📞 Processing Incoming Call From: \(callerName) with UUID: \(uuidString)")

        // 🚀 STEP 1: Show native CallKit UI screen instantly
        CallManager.shared.reportIncomingCall(uuid: uuid, handle: callerName)

        // 🚀 STEP 2: Tell Apple watchdog that push processing is done immediately
        completion()
        print("✅ Apple push execution lifecycle closed safely.")

        // 🚀 STEP 3: Async dispatch to Flutter
        DispatchQueue.main.async { [weak self] in
            self?.callChannel?.invokeMethod(
                "onIncomingVoipCall",
                arguments: [
                    "uuid": uuidString,
                    "callerName": callerName
                ]
            )
            print("📱 Delayed background payload dispatched to Flutter channel")
        }
    }
    
    // MARK: - NATIVE NOTIFICATION OBSERVER (END CALL)
    @objc private func handleNativeCallEnd(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let uuidStr = userInfo["uuid"] as? String {
            print("🧹 Cleaning up call reference in AppDelegate for: \(uuidStr)")
            if self.currentCallUUID == uuidStr.lowercased() {
                self.currentCallUUID = nil
            }
            
            callChannel?.invokeMethod("onCallEndedNatively", arguments: ["uuid": uuidStr.lowercased()])
        }
    }

    // MARK: - NATIVE NOTIFICATION OBSERVER (ANSWER CALL)
    @objc private func handleNativeCallAnswered(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let uuidStr = userInfo["uuid"] as? String {
            print("📲 Native Call Answered Linker Hooked for UUID: \(uuidStr)")
            
            callChannel?.invokeMethod(
                "onNativeCallAnswered",
                arguments: ["uuid": uuidStr.lowercased()]
            )
            print("✅ Flutter notified via channel event: onNativeCallAnswered")
        }
    }
}
