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
    
    // Caching Variables
    var cachedVoipTokenString: String?
    var pendingAnsweredCallUUID: String? // 🔥 Stores UUID if Flutter is not yet active

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
            }
            // 🔥 NEW: Flutter handles force check on boot-up for killed/lock state calls
            else if call.method == "checkPendingAnsweredCall" {
                if let pendingUuid = self?.pendingAnsweredCallUUID {
                    print("🚀 Sending pending answered call to Flutter: \(pendingUuid)")
                    result(["uuid": pendingUuid])
                    self?.pendingAnsweredCallUUID = nil // Clear cache after handing over
                } else {
                    result(nil) // No pending calls found
                }
            }
            else {
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
        // PUSHKIT SETUP (VoIP Pushes)
        // ==========================================
        voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
        voipRegistry?.delegate = self
        voipRegistry?.desiredPushTypes = [.voIP]

        // Call-end observer: fired by CallManager when the user ends via CallKit.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNativeCallEnd(_:)),
            name: NSNotification.Name("CALL_ENDED_NATIVE"),
            object: nil
        )

        // Call-answer observer: fired by CallManager when the user answers via CallKit.
        // CallManager.tryNotifyFlutter() already handles retrying the channel call; this
        // observer provides the fallback cache path (pendingAnsweredCallUUID) for very
        // slow engine starts where all 20 retries are exhausted before Dart is ready.
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
        // Create the new registry BEFORE releasing the old one to avoid a brief
        // window where voipRegistry == nil and an incoming VoIP push would be lost.
        let newRegistry = PKPushRegistry(queue: DispatchQueue.main)
        newRegistry.delegate = self
        newRegistry.desiredPushTypes = [.voIP]
        voipRegistry = newRegistry  // old registry released only after new one is set
    }

    // MARK: - VOIP TOKEN RECEIVED
    func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()
        print("📲 VoIP Token: \(token)")
        
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

    // #changedWithJClaude — Bug 2: extract callerNumber/callId/session from VoIP payload and
    // write them to NSUserDefaults (=SharedPreferences on iOS) before showing CallKit.
    // This guarantees SDP is available at answer time even in killed state.
    // MARK: - INCOMING VOIP PUSH
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        print("🔥 VOIP PUSH RECEIVED IN APPDELEGATE")

        let data = payload.dictionaryPayload
        print("📦 Payload Data: \(data)")

        // Server now sends a stable UUID v5 derived from call_id (same algorithm as
        // Flutter's _getValidCallKitId).  Fall back to UUID().uuidString only when the
        // field is absent (older server versions), ensuring both push paths always share
        // the same UUID for a given call.
        let rawUuidString = (data["uuid"] as? String)?.lowercased()
            ?? (data["call_id"] as? String)?.lowercased()
            ?? UUID().uuidString
        let uuidString = rawUuidString.lowercased()

        // Support both camelCase and snake_case field names from server
        let callerName = (data["callerName"] as? String)
            ?? (data["caller_name"] as? String)
            ?? "Incoming Call"
        let callerNumber = (data["callerNumber"] as? String)
            ?? (data["caller_number"] as? String)
            ?? ""
        let callId = (data["callId"] as? String)
            ?? (data["call_id"] as? String)
            ?? uuidString
        let sessionRaw = (data["session"] as? String) ?? ""

        // Persist call metadata into NSUserDefaults so Flutter's SharedPreferences
        // (which maps to NSUserDefaults on iOS) can read SDP/callId at answer time.
        // This is the single source of truth for killed-state call data.
        // SharedPreferences on iOS (shared_preferences_foundation v2.x) prefixes every
        // key with "flutter." before writing to NSUserDefaults.  Writing plain keys here
        // means Flutter can never read them.  Use the same prefix so both sides share data.
        let defaults = UserDefaults.standard
        defaults.set(callId,      forKey: "flutter.pending_call_id")
        defaults.set(callerName,  forKey: "flutter.pending_caller_name")
        defaults.set(callerNumber,forKey: "flutter.pending_caller_number")
        defaults.set(uuidString,  forKey: "flutter.pending_callkit_id")
        if !sessionRaw.isEmpty {
            defaults.set(sessionRaw, forKey: "flutter.pending_call_session")
        }
        print("📦 Call metadata written to NSUserDefaults for killed-state recovery")

        guard let uuid = UUID(uuidString: uuidString) else {
            print("❌ Invalid UUID string received: \(uuidString)")
            completion()
            return
        }

        self.currentCallUUID = uuidString
        print("📞 Processing Incoming Call From: \(callerName) with UUID: \(uuidString)")

        // Show CallKit Screen Instantly
        CallManager.shared.reportIncomingCall(uuid: uuid, handle: callerName)

        completion()
        print("✅ Apple push execution lifecycle closed safely.")

        // Async dispatch to Flutter (if Flutter is already awake)
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
            let cleanUuid = uuidStr.lowercased()
            // ALWAYS cache — never invoke the channel directly here.
            // tryNotifyFlutter (already running concurrently) is the live-invocation
            // path and clears this cache when it succeeds, preventing double-fire.
            // checkPendingAnsweredCall() is the killed-state fallback if all retries
            // exhaust before Dart starts.
            print("📲 Native Call Answered — UUID cached for recovery: \(cleanUuid)")
            self.pendingAnsweredCallUUID = cleanUuid
        }
    }
}
