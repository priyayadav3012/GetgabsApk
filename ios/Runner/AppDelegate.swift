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
    var pendingAnsweredCallUUID: String? // Stores UUID if Flutter is not yet active/booted

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
            // 🔥 Flutter handles force check on boot-up for killed/lock state calls
            else if call.method == "checkPendingAnsweredCall" {
                if let pendingUuid = self?.pendingAnsweredCallUUID {
                    print("🚀 Sending pending answered call to Flutter on boot: \(pendingUuid)")
                    result(["uuid": pendingUuid])
                    self?.pendingAnsweredCallUUID = nil // Clear cache after successful handover
                } else {
                    result(nil) // No pending calls found
                }
            }
            else if call.method == "getNativeCallUUID" {
                // Returns the active native CallKit UUID set by PushKit, or nil if none.
                // Flutter uses this to detect if native CallKit is already showing before
                // deciding whether to show its own Flutter CallKit (prevents double call UI).
                result(self?.currentCallUUID)
            }
            else if call.method == "setupAudioSession" {
                // Called by Flutter after answerCall() succeeds to ensure AVAudioSession
                // is correctly configured for WebRTC audio (voiceChat mode).
                do {
                    let audioSession = AVAudioSession.sharedInstance()
                    try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP])
                    try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                    print("✅ [AppDelegate] Audio session configured for WebRTC (voiceChat).")
                    result(true)
                } catch {
                    print("❌ [AppDelegate] Audio session setup error: \(error.localizedDescription)")
                    result(FlutterError(code: "AUDIO_SESSION_ERROR", message: error.localizedDescription, details: nil))
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

        // 1. Native Call End Lifecycle Linker
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNativeCallEnd(_:)),
            name: NSNotification.Name("CALL_ENDED_NATIVE"),
            object: nil
        )

        // 2. Native Call Answer Lifecycle Linker
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNativeCallAnswered(_:)),
            name: NSNotification.Name("CALL_ANSWERED_NATIVE"),
            object: nil
        )

        // 3. Audio session activation — tells Flutter WebRTC the audio session is ready
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionActivated),
            name: NSNotification.Name("CALLKIT_AUDIO_SESSION_ACTIVATED"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionDeactivated),
            name: NSNotification.Name("CALLKIT_AUDIO_SESSION_DEACTIVATED"),
            object: nil
        )

        // Force Initialize the CallManager Singleton early
        _ = CallManager.shared

        print("✅ [AppDelegate] PushKit, CallKit & Listeners Fully Initialized")

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
        print("📲 VoIP Token Generated: \(token)")
        
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

    // MARK: - INCOMING VOIP PUSH (System Boot Trigger)
    func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        print("🔥 VOIP PUSH RECEIVED IN APPDELEGATE")

        let data = payload.dictionaryPayload
        print("📦 Payload Data: \(data)")

        let rawUuidString = data["uuid"] as? String ?? UUID().uuidString
        let uuidString = rawUuidString.lowercased()
        // Try every field the server might use for the caller name
        let callerName = (data["callerName"] as? String
            ?? data["caller_name"] as? String
            ?? data["name"] as? String
            ?? data["displayName"] as? String
            ?? data["pushName"] as? String
            ?? data["notify"] as? String
            ?? "").trimmingCharacters(in: .whitespaces)
        let displayName = callerName.isEmpty ? "Incoming Call" : callerName

        guard let uuid = UUID(uuidString: uuidString) else {
            print("❌ Invalid UUID string received: \(uuidString)")
            completion()
            return
        }

        // Dedup: agar same UUID ya koi aur call pehle se active hai to skip karo
        // PushKit poor network mein same push 2+ baar deliver kar sakta hai
        if self.currentCallUUID != nil {
            print("⚠️ [AppDelegate] Native CallKit already active (UUID: \(self.currentCallUUID!)) — ignoring duplicate push for: \(uuidString)")
            completion()
            return
        }

        self.currentCallUUID = uuidString
        print("📞 Processing Incoming Call From: \(displayName) with UUID: \(uuidString)")

        // 🚀 CRITICAL: Report incoming call directly to CallKit instantly
        CallManager.shared.reportIncomingCall(uuid: uuid, handle: displayName)

        completion()
        print("✅ Apple push execution lifecycle closed safely.")

        // Async dispatch to Flutter engine
        DispatchQueue.main.async { [weak self] in
            self?.callChannel?.invokeMethod(
                "onIncomingVoipCall",
                arguments: [
                    "uuid": uuidString,
                    "callerName": displayName
                ]
            )
            print("📱 Delayed background payload dispatched to Flutter channel")
        }
    }
    
    // MARK: - NATIVE NOTIFICATION OBSERVERS
    
    @objc private func handleAudioSessionActivated() {
        print("🎵 [AppDelegate] Audio session activated — notifying Flutter WebRTC.")
        callChannel?.invokeMethod("onAudioSessionActivated", arguments: nil)
    }

    @objc private func handleAudioSessionDeactivated() {
        print("🔇 [AppDelegate] Audio session deactivated — notifying Flutter WebRTC.")
        callChannel?.invokeMethod("onAudioSessionDeactivated", arguments: nil)
    }

    @objc private func handleNativeCallEnd(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let uuidStr = userInfo["uuid"] as? String {
            let cleanUuid = uuidStr.lowercased()
            print("🧹 Cleaning up call reference in AppDelegate for: \(cleanUuid)")

            // Clear if UUID matches OR if provider reset sent empty UUID (clears all)
            if cleanUuid.isEmpty || self.currentCallUUID == cleanUuid {
                self.currentCallUUID = nil
            }

            callChannel?.invokeMethod("onCallEndedNatively", arguments: ["uuid": cleanUuid])
        }
    }

    @objc private func handleNativeCallAnswered(_ notification: Notification) {
        if let userInfo = notification.userInfo,
           let uuidStr = userInfo["uuid"] as? String {
            let cleanUuid = uuidStr.lowercased()
            print("📲 Native Call Answered Linker Hooked for UUID: \(cleanUuid)")

            // Always cache first — handles cold boot, lock screen, and background cases.
            self.pendingAnsweredCallUUID = cleanUuid

            if UIApplication.shared.applicationState == .active {
                // App already active — deliver to Flutter immediately.
                self.pendingAnsweredCallUUID = nil
                callChannel?.invokeMethod("onNativeCallAnswered", arguments: ["uuid": cleanUuid])
                print("✅ Flutter notified instantly: onNativeCallAnswered")
            } else {
                // App in background/transitioning — applicationDidBecomeActive will deliver it.
                print("⏳ App not active — answer cached, will deliver on applicationDidBecomeActive.")
            }
        }
    }

    // Handles: lock screen answer, background answer, killed-app answer.
    // When user answers native CallKit while app is not active, this fires
    // once the app comes to foreground and delivers the cached answer to Flutter.
    override func applicationDidBecomeActive(_ application: UIApplication) {
        super.applicationDidBecomeActive(application)
        guard let pendingUuid = self.pendingAnsweredCallUUID, callChannel != nil else { return }
        print("📲 [AppDelegate] App became active — delivering pending answered call: \(pendingUuid)")
        self.pendingAnsweredCallUUID = nil
        callChannel?.invokeMethod("onNativeCallAnswered", arguments: ["uuid": pendingUuid])
    }
}