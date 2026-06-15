# Background / Killed-State Call Fix Summary

**Author:** JK + Claude  
**Branch:** `call-disconnect-bug`  
**Marker:** All changed code blocks are tagged `// #changedWithJClaude`

---

## Problem Statement

Incoming VoIP calls worked correctly in foreground but failed in two specific states:

- **Background:** CallKit accepted the call but audio never connected to the other side.
- **Killed state:** Same symptom — CallKit UI appeared and accepted, but no WebRTC session was established.

---

## Root Causes Found (6 bugs)

### Bug 1 — Killed state: Flutter channel never received the answer event
**File:** `ios/Runner/CallManager.swift`

`CXAnswerCallAction` fired with a single 0.3-second delay before notifying Flutter. In killed state, the Flutter engine takes 1–3 seconds to initialise, so `callChannel` was `nil` at 0.3 s and the invocation silently dropped via optional chaining. `pendingAnsweredCallUUID` was never set because the `CALL_ANSWERED_NATIVE` notification (which `AppDelegate.handleNativeCallAnswered` listens to) was never posted by `CallManager`. Result: Flutter never knew the call was answered.

**Fix:** Replaced the single attempt with a 20-retry loop (0.5 s each = 10 s window). On exhaustion, the UUID is written to `pendingAnsweredCallUUID` so `checkPendingAnsweredCall` can recover it when Flutter loads.

---

### Bug 2 — Killed state: SDP not available at answer time
**File:** `ios/Runner/AppDelegate.swift`

The VoIP push payload only carried `uuid` and `callerName`. The SDP was stored by the FCM background handler (`_firebaseMessagingBackgroundHandler`) but there was a race: the user could accept the native CallKit UI before the FCM handler had written to `SharedPreferences`.

**Fix:** `pushRegistry(_:didReceiveIncomingPushWith:)` now extracts `callerName`, `callerNumber`, `callId`, and `session` (SDP) from the VoIP payload and writes them to `NSUserDefaults` (which is the same backing store as Flutter's `SharedPreferences` on iOS) before showing CallKit. This is the authoritative source of SDP for the killed-state answer path. Both camelCase and snake_case field names from the server are supported.

---

### Bug 3 — Dual CallKit providers: mismatched UUIDs
**File:** `lib/main.dart`

Two independent `CXProvider` instances were active simultaneously on iOS:
1. Native `CallManager.swift` — triggered by VoIP push
2. `flutter_callkit_incoming` plugin — triggered by the FCM background handler

The plugin used a freshly generated random UUID each time, so the UUID in `flutter_callkit_incoming` never matched the UUID the native provider (and the server) knew about.

**Fix:** Instead of suppressing the `flutter_callkit_incoming` display on iOS (which caused a regression — see below), the UUID is now aligned: the FCM handler reads `pending_callkit_id` from prefs (written by `AppDelegate.pushRegistry` the moment the VoIP push arrives, which on iOS is always before FCM). If that UUID is present it is reused; otherwise a new one is generated. Because VoIP push has higher delivery priority than APNs/FCM on iOS, in practice both providers now refer to the same UUID. If native CallKit showed first, iOS silently rejects the duplicate `flutter_callkit_incoming` report and the native UI stays. Both answer paths (native `onNativeCallAnswered` and plugin `CallEventActionCallAccept`) work correctly with the Bug 4 fix in place.

> **Regression note:** An earlier version of this fix returned early on iOS without showing `flutter_callkit_incoming` at all, assuming VoIP push would always work. This broke the CallKit UI in background — only the FCM notification banner was shown. The current fix keeps `flutter_callkit_incoming` as the safety net on iOS.

---

### Bug 4 — Background: `answerCall()` called with no active audio session
**File:** `lib/domain/services/whtasapp_calling_service.dart` (`GlobalCallListenerService._callkitSubscription`)

When the app was in background and the user accepted via CallKit, the background path called `_waitForSocketConnected` (up to 12 s) then `answerCall()`. `answerCall()` internally calls `getUserMedia()`, which requires an active iOS audio session. The audio session is only truly activated by `provider(_:didActivate:audioSession:)` — a CallKit callback that only fires after the CallKit UI is visible in the foreground. In background, `getUserMedia()` either returned an unusable track or silently threw, making the WebRTC connection impossible. The 12-second socket-wait also raced the server's call timeout. The fallback `_quickAcceptToServer` sent no SDP answer, so the server could never complete the handshake either.

**Fix:** The background branch now only stores `_pendingNavigation` and returns. The full WebRTC handshake (`answerCall()`) happens inside `IncomingCallScreen.initState()` after the app foregrounds and CallKit has activated the audio session. The now-unused `_waitForSocketConnected` and `_quickAcceptToServer` helpers were deleted.

---

### Bug 5 — `GlobalCallListenerService.initialize()` tore down the service mid-call
**File:** `lib/domain/services/whtasapp_calling_service.dart` (`GlobalCallListenerService.initialize`)

The old guard was `if (_isInitialized && socket?.connected == true) return`. When `onNativeCallAnswered` arrived (socket might have dropped momentarily in background), this guard failed and the service was fully torn down — disconnecting the socket, calling `cleanupCall()`, and nulling `_service`. Any SDP previously stored via `setPendingCall()` was lost on the new instance.

**Fix:** A new guard checks for an active or pending call first. If one exists, the socket is reconnected (if needed) without tearing down the service. The full teardown only runs when no call is in progress.

---

### Bug 6 — Foreground resume: 800 ms delay too slow
**File:** `lib/main.dart` (`AppLifecycleObserver`)

When the user accepted a background call and the app came to foreground, `handlePendingCallNavigation()` was called after an 800 ms delay. Combined with socket reconnect time, `getUserMedia`, and SDP exchange, the total latency between "user taps Accept" and "SDP answer reaches server" could exceed 15 seconds — long enough for the caller to hang up.

**Fix:** Delay reduced from 800 ms to 100 ms.

---

## Files Changed

| File | Bug(s) | Nature of change |
|------|--------|-----------------|
| `ios/Runner/CallManager.swift` | 1 | Replaced single 0.3 s attempt with 20-retry loop; new `tryNotifyFlutter` helper |
| `ios/Runner/AppDelegate.swift` | 2 | Write full call metadata to `NSUserDefaults` on VoIP push arrival |
| `lib/main.dart` | 3, 6 | UUID alignment in FCM handler for iOS (reuse VoIP UUID); foreground delay 800 ms → 100 ms |
| `lib/domain/services/whtasapp_calling_service.dart` | 4, 5 | Removed `answerCall()` + dead helpers from background path; guarded `initialize()` against mid-call teardown |

---

## Server-Side Recommendation

For Bug 2 to be fully covered regardless of FCM delivery timing, the server should include the SDP in the VoIP push payload itself under the key `session` (same JSON format as the FCM push: `{"sdp":"...","sdp_type":"offer"}`). `AppDelegate.swift` already reads and stores this key. If the server cannot include SDP in the VoIP push, the FCM-first path (storing before VoIP arrives) must be guaranteed by the server's push ordering.

---

## How to Verify

1. **Killed state:** Force-quit the app, receive a call, accept from the native CallKit lock-screen UI. The app should open directly to the call screen and audio should connect within a few seconds.
2. **Background state:** Put the app in background, receive a call, accept from the CallKit banner. The app should foreground to the call screen and connect.
3. **Foreground state:** Receive a call while the app is open — behaviour unchanged, still uses the in-app CallKit popup.
4. Check Xcode console for `✅ Flutter notified: onNativeCallAnswered (attempt N)` to confirm which retry index was needed for killed vs background.
