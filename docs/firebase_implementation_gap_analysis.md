# Firebase Implementation Gap Analysis

## Purpose

This document reviews the current Firebase implementation in the Flutter app with emphasis on chat messages, call handling, and background or killed-state notifications. The goal is to identify functional gaps, operational risks, and practical remediation steps.

## Scope

The analysis covers:

- Firebase Messaging initialization and background handling
- Chat message delivery and notification behavior
- Incoming call delivery and CallKit / PushKit behavior
- Notification tap handling and navigation
- Device token registration and backend targeting
- iOS and Android platform-specific notification flow

## Executive Summary

The call stack is more complete than the chat stack, especially on iOS where PushKit and CallKit are wired through native code. Chat delivery is still heavily dependent on sockets and foreground app state. The main gaps are incomplete Android token persistence, incomplete killed-state chat notification handling, and a committed service account private key in source code.

The result is a system that can behave well while the app is open, but is not yet reliable enough for background or terminated-state chat delivery.

## Audit Findings

| ID | Severity | Area | Evidence | Remediation |
|---|---|---|---|---|
| F-01 | Critical | Secret management | Service account credentials are embedded in [get_server_key.dart](../lib/domain/services/notifications_service/get_server_key.dart#L1). | Remove the secret from the repo, rotate the key, and move Firebase server auth to a secure backend or secret manager. |
| F-02 | High | Android token sync | [syncDeviceTokensToServer](../lib/domain/controllers/auth/login_with_email/login_with_email_controller.dart#L161) does not persist the Android FCM token, even though login triggers sync at [login_with_email_controller.dart](../lib/domain/controllers/auth/login_with_email/login_with_email_controller.dart#L262). | Save Android FCM tokens on login and token refresh so the backend can target Android devices. |
| F-03 | High | Chat push delivery | Message send flows in [messages_page_controller.dart](../lib/domain/controllers/dashboard/messages_page/messages_page_controller.dart#L779) and [messages_page_controller.dart](../lib/domain/controllers/dashboard/messages_page/messages_page_controller.dart#L894) only call the chat API. | Make the backend emit FCM for inbound chat messages with enough metadata to route the notification. |
| F-04 | High | Background chat notifications | The socket notification path in [sockets_controller.dart](../lib/domain/controllers/sockets/sockets_controller.dart#L438) only shows notifications when `isAppInForeground` is true. | Use sockets for live updates only and add an FCM path for background and killed-state chat delivery. |
| F-05 | High | Background routing | In [main.dart](../lib/main.dart#L60), the `new_message` branch only stores a refresh flag at [main.dart](../lib/main.dart#L153). | Persist conversation metadata and consume it on resume or launch so the correct chat opens. |
| F-06 | Medium | Notification bootstrap | `initLocalNotifications` is defined in [notification_service.dart](../lib/domain/services/notifications_service/notification_service.dart#L60) but no call site was found. | Invoke notification initialization during app startup so tap handling is registered before pushes arrive. |
| F-07 | Medium | Notification architecture | Firebase notification logic and socket local notifications live in separate services. | Consolidate unread handling, tap routing, and display logic into one notification boundary. |
| F-08 | Medium | Call payload contract | iOS PushKit/CallKit are wired in [AppDelegate.swift](../ios/Runner/AppDelegate.swift#L91) and [AppDelegate.swift](../ios/Runner/AppDelegate.swift#L146), while Android call handling depends on exact push types in [main.dart](../lib/main.dart#L60). | Document the backend payload contract and add defensive parsing plus integration tests. |

## Detailed Analysis

### 1. Chat Messages

Current state:

- Messages are sent through the chat API.
- Live updates are received through socket listeners.
- Foreground users may see local notifications from socket events.

Gaps:

- No client-side push fan-out after message send.
- No guaranteed FCM delivery path for background or killed app states.
- No strong evidence that notification taps reopen the correct chat thread.
- The FCM background handler only stores a refresh flag without using it.

Impact:

- A user can miss new messages when the app is backgrounded or terminated.
- Read and unread state may drift if a push is not received or handled.
- Notification behavior is inconsistent between live and offline app states.

### 2. Call Handling

Current state:

- iOS has native PushKit and CallKit support.
- Incoming VoIP pushes are handled in native code and forwarded to Flutter.
- Flutter call lifecycle management is implemented for incoming and outgoing calls.

Gaps:

- Android call delivery depends on backend payload consistency.
- There is no in-repo proof that the backend always sends the exact call push contract.
- Call delivery on Android is more fragile than iOS and depends on the FCM background handler.

Impact:

- iOS calling is relatively robust.
- Android calling may fail silently if payloads, tokens, or push targets are not correct.
- Killed-state behavior is fragile if backend pushes do not match expectations.

### 3. Notifications and Background State

Current state:

- Notification service exists and is initialized from the dashboard controller.
- Topic subscription and Firebase Messaging setup are present.
- Background handling exists for some call and message cases.

Gaps:

- Local notification initialization is defined but not clearly invoked.
- The app uses separate notification paths for socket and Firebase events.
- Background and killed-state UX is incomplete for chat.

Impact:

- Notification delivery and tap routing are not uniform.
- Users may receive notifications without proper navigation behavior.
- App reopen behavior after a notification tap may not be reliable.

### 4. Token Registration and Backend Targeting

Current state:

- FCM token retrieval exists.
- iOS VoIP token retrieval exists.
- Login flow attempts token sync.

Gaps:

- Android FCM token is not visibly persisted to the backend.
- Token sync behavior differs between platforms.
- The client contains a service account key that should never be shipped.

Impact:

- The backend may not be able to send pushes to Android devices.
- Security exposure exists due to credential leakage.
- Push reliability cannot be guaranteed across the user base.

## Root Cause Assessment

The core issue is architectural inconsistency:

- Sockets are used for live chat updates.
- Firebase is used for push and background events.
- Native iOS code handles calls well.
- Android push registration and chat push behavior are incomplete.

This creates a split system where the app behaves correctly while open, but becomes unreliable when backgrounded or terminated.

## Risk Summary

### Critical Risk

- Exposed service account private key in source code

### High Risks

- Android FCM token not persisted to backend
- Chat notifications not implemented as a true offline push path
- Socket-based notifications do not work in killed state
- FCM background chat handler does not complete the user journey

### Medium Risks

- Local notification initialization not clearly invoked
- Notification routing split across multiple systems
- Call delivery contract depends on backend payload shape

## Recommended Remediation

### Priority 1

- Remove the embedded service account private key and rotate it immediately.
- Persist Android FCM tokens to the backend.
- Confirm the backend can target both chat and call pushes correctly.

### Priority 2

- Implement a real killed-state chat notification path.
- Ensure notification tap handling restores the correct chat conversation.
- Invoke local notification initialization during startup.

### Priority 3

- Unify notification routing under one service.
- Define and document push payload contracts for chat and calls.
- Add validation or tests for background message parsing and tap navigation.

## Verification Checklist

- Android FCM token is saved on login.
- iOS VoIP token is saved and reused correctly.
- Chat notifications appear in background and killed states.
- Tapping a notification opens the correct conversation.
- Incoming call pushes work on iOS and Android according to contract.
- No secrets remain committed in the client repository.

## Conclusion

The app’s call stack is notably stronger than the chat stack, especially on iOS. The main functional gap is that chat delivery is still not fully push-driven for background and killed states. The highest-risk issue is the committed service account key, followed by incomplete Android token persistence and the lack of a complete chat notification lifecycle.