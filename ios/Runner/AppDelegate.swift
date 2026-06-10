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
    var cachedVoipTokenString: String?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        GeneratedPluginRegistrant.register(with: self)

        guard let controller = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

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
            } else if call.method == "getVoipTokenForcefully" {
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

        FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
            GeneratedPluginRegistrant.register(with: registry)
        }

        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
        }

        voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
        voipRegistry?.delegate = self
        voipRegistry?.desiredPushTypes = [.voIP]

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNativeCallEnd(_:)),
            name: NSNotification.Name("CALL_ENDED_NATIVE"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNativeCallAnswered(_:)),
            name: NSNotification.Name("CALL_ANSWERED_NATIVE"),
            object: nil
        )

        print("✅ PushKit and CallKit Event Listeners Initialized")
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func retriggerVoipRegistration() {
        voipRegistry = nil
        voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
        voipRegistry?.delegate = self
        voipRegistry?.desiredPushTypes = [.voIP]
    }

    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        print("📲 VoIP Token: \(token)")
        self.cachedVoipTokenString = token
        callChannel?.invokeMethod("onVoipTokenReceived", arguments: token)
    }

    func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        print("❌ VoIP Token Invalidated")
        self.cachedVoipTokenString = nil
        callChannel?.invokeMethod("onVoipTokenInvalid", arguments: nil)
    }

    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        print("🔥 VOIP PUSH RECEIVED IN APPDELEGATE")

        let data = payload.dictionaryPayload
        print("📦 Payload Data: \(data)")

        let rawUuidString = (data["uuid"] as? String ?? UUID().uuidString).lowercased()
        let callerName = data["callerName"] as? String ?? "Incoming Call"
        let callerNumber = data["callerNumber"] as? String ?? ""
        let backendCallId =
            (data["callId"] as? String ??
             data["call_id"] as? String ??
             data["id"] as? String ??
             "").trimmingCharacters(in: .whitespacesAndNewlines)

        guard let uuid = UUID(uuidString: rawUuidString) else {
            print("❌ Invalid UUID string received: \(rawUuidString)")
            completion()
            return
        }

        self.currentCallUUID = rawUuidString
        print("📞 Processing Incoming Call From: \(callerName) with UUID: \(rawUuidString)")

        if let sessionObj = data["session"] {
            var sessionStr: String
            if let s = sessionObj as? String {
                sessionStr = s
            } else if JSONSerialization.isValidJSONObject(sessionObj) {
                if let d = try? JSONSerialization.data(withJSONObject: sessionObj, options: []),
                   let s = String(data: d, encoding: .utf8) {
                    sessionStr = s
                } else {
                    sessionStr = ""
                }
            } else {
                sessionStr = ""
            }

            if !sessionStr.isEmpty {
                UserDefaults.standard.setValue(sessionStr, forKey: "pending_call_session")
            }
        }

        UserDefaults.standard.setValue(callerNumber, forKey: "pending_caller_number")
        UserDefaults.standard.setValue(callerName, forKey: "pending_caller_name")
        UserDefaults.standard.setValue(rawUuidString, forKey: "pending_callkit_id")
        UserDefaults.standard.setValue(backendCallId.isEmpty ? rawUuidString : backendCallId, forKey: "pending_call_id")
        UserDefaults.standard.setValue(data["from_user_id"], forKey: "pending_from_user_id")

        CallManager.shared.reportIncomingCall(uuid: uuid, handle: callerName)

        completion()
        print("✅ Apple push execution lifecycle closed safely.")

        DispatchQueue.main.async { [weak self] in
            self?.callChannel?.invokeMethod(
                "onIncomingVoipCall",
                arguments: [
                    "uuid": rawUuidString,
                    "callkitId": rawUuidString,
                    "callId": backendCallId.isEmpty ? rawUuidString : backendCallId,
                    "callerName": callerName,
                    "callerNumber": callerNumber,
                    "session": UserDefaults.standard.string(forKey: "pending_call_session") ?? ""
                ]
            )
            print("📱 Delayed background payload dispatched to Flutter channel")
        }
    }

    @objc private func handleNativeCallEnd(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let uuidStr = userInfo["uuid"] as? String {
            let normalized = uuidStr.lowercased()
            print("🧹 Cleaning up call reference in AppDelegate for: \(normalized)")
            if self.currentCallUUID == normalized {
                self.currentCallUUID = nil
            }

            callChannel?.invokeMethod("onCallEndedNatively", arguments: [
                "uuid": normalized,
                "callkitId": UserDefaults.standard.string(forKey: "pending_callkit_id") ?? normalized,
                "callId": UserDefaults.standard.string(forKey: "pending_call_id") ?? normalized
            ])
        }
    }

    @objc private func handleNativeCallAnswered(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let uuidStr = userInfo["uuid"] as? String {
            let normalized = uuidStr.lowercased()
            print("📲 Native Call Answered Linker Hooked for UUID: \(normalized)")

            callChannel?.invokeMethod(
                "onNativeCallAnswered",
                arguments: [
                    "uuid": normalized,
                    "callkitId": UserDefaults.standard.string(forKey: "pending_callkit_id") ?? normalized,
                    "callId": UserDefaults.standard.string(forKey: "pending_call_id") ?? normalized,
                    "session": UserDefaults.standard.string(forKey: "pending_call_session") ?? "",
                    "callerName": UserDefaults.standard.string(forKey: "pending_caller_name") ?? "",
                    "callerNumber": UserDefaults.standard.string(forKey: "pending_caller_number") ?? "",
                    "answeredInBackground": UIApplication.shared.applicationState == .background
                ]
            )
            print("✅ Flutter notified via channel event: onNativeCallAnswered")
        }
    }
}
