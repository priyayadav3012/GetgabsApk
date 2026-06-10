# Firebase Audit TODO List

This document turns the audit findings into a repo-scoped implementation checklist. It stays within files that exist in this workspace and marks cases where the remediation depends on backend or other non-repo work.

## F-01 - Secret management

Files:

- [lib/domain/services/notifications_service/get_server_key.dart](../lib/domain/services/notifications_service/get_server_key.dart)
- [lib/domain/services/notifications_service/notification_service.dart](../lib/domain/services/notifications_service/notification_service.dart)

TODOs:

- Remove the embedded Firebase service account/private key material from `get_server_key.dart`.
- Remove any client-side code that mints Firebase access tokens from the embedded credential.
- Replace direct client Firebase server auth with a backend endpoint or a secret-manager backed service.
- Rotate the exposed key after removal from the client repository.

Verification:

- Search the repo and confirm there is no remaining service-account JSON or private-key string in client code.
- Confirm notification sending still works after routing through the secure backend path.

Dependency note:

- This remediation requires backend or secret-management work outside the Flutter repo.

## F-02 - Android token sync

Files:

- [lib/domain/controllers/auth/login_with_email/login_with_email_controller.dart](../lib/domain/controllers/auth/login_with_email/login_with_email_controller.dart)
- [lib/domain/services/remote_services/remote_auth_service.dart](../lib/domain/services/remote_services/remote_auth_service.dart)
- [lib/domain/end_points/api_end_points.dart](../lib/domain/end_points/api_end_points.dart)

TODOs:

- Add Android FCM token persistence to `syncDeviceTokensToServer` instead of logging the token only.
- Ensure the Android login path sends the token using the same update-tokens API contract that the iOS path already uses.
- Add token-refresh handling so a refreshed Android token is also persisted.
- Confirm the backend stores the Android token and makes it available for push targeting.

Verification:

- Log in on Android and confirm the backend receives a persisted FCM token.
- Trigger a token refresh and confirm the updated token replaces the previous one.

Dependency note:

- This needs a backend token storage endpoint or an existing update-tokens flow that accepts Android tokens.

## F-03 - Chat push delivery

Files:

- [lib/domain/controllers/dashboard/messages_page/messages_page_controller.dart](../lib/domain/controllers/dashboard/messages_page/messages_page_controller.dart)

TODOs:

- Keep the current chat API send path intact.
- Add or confirm backend fan-out so inbound chat messages generate FCM pushes for the recipient.
- Ensure the push payload includes enough metadata to route the notification to the right conversation.
- Confirm the send flow does not rely on the client alone for offline delivery.

Verification:

- Send a message while the recipient app is backgrounded or terminated and confirm a push arrives.
- Open the notification and confirm it routes to the intended chat thread.

Dependency note:

- This is primarily backend work; the Flutter repo alone cannot create the missing push delivery path.

## F-04 - Background chat notifications

Files:

- [lib/domain/controllers/sockets/sockets_controller.dart](../lib/domain/controllers/sockets/sockets_controller.dart)

TODOs:

- Keep sockets as the live foreground update channel.
- Do not depend on socket-driven local notifications for background or killed-state chat delivery.
- Add or confirm an FCM-based delivery path for chat notifications when the app is not foregrounded.
- Preserve the current foreground socket behavior while separating it from offline delivery.

Verification:

- Background the app and send a chat message; confirm the user still receives a push notification.
- Return the app to foreground and confirm socket live updates still work.

Dependency note:

- This requires backend push delivery in addition to the existing socket flow.

## F-05 - Background routing

Files:

- [lib/main.dart](../lib/main.dart)

TODOs:

- Replace the current `new_message` branch that only stores a refresh flag.
- Persist conversation metadata needed to reopen the correct chat thread.
- Add resume or launch-time consumption of the stored metadata so the app navigates to the correct conversation.
- Keep the current refresh behavior only if it is still needed for unread-state updates.

Verification:

- Cold-start the app from a new-message notification and confirm the intended chat opens.
- Resume the app from background and confirm the same routing behavior works.

Dependency note:

- This is mostly repo-side work; backend changes are only needed if the current push payload lacks thread identifiers.

## F-06 - Notification bootstrap : Done - to be tested
refer to [F-06_notification_bootstrap.md] file for implementation details.

Files:

- [lib/domain/services/notifications_service/notification_service.dart](../lib/domain/services/notifications_service/notification_service.dart)
- [lib/domain/controllers/dashboard/dashboard_controller.dart](../lib/domain/controllers/dashboard/dashboard_controller.dart)

TODOs:

- Add a startup call site for `initLocalNotifications`.
- Refactor the notification initialization so it runs once during app startup instead of requiring a `RemoteMessage` at setup time.
- Ensure tap handling is registered before the first push can arrive.
- Keep the rest of the notification display flow unchanged unless initialization requires a small API adjustment.

Verification:

- Launch the app from a cold start and confirm a notification tap is handled without a prior push setup.
- Confirm notification initialization is present before any remote message arrives.

Dependency note:

- This is repo-only work.

## F-07 - Notification architecture

Files:

- [lib/domain/services/notifications_service/notification_service.dart](../lib/domain/services/notifications_service/notification_service.dart)
- [lib/domain/controllers/sockets/sockets_controller.dart](../lib/domain/controllers/sockets/sockets_controller.dart)
- [lib/domain/controllers/dashboard/dashboard_controller.dart](../lib/domain/controllers/dashboard/dashboard_controller.dart)

TODOs:

- Consolidate notification display and tap routing under one boundary.
- Remove duplicate or parallel notification handling paths where socket notifications and Firebase notifications overlap.
- Keep unread-state handling, display logic, and routing logic aligned across foreground and background events.
- Ensure the dashboard layer consumes one consistent notification outcome rather than separate implementations.

Verification:

- Exercise foreground, background, and notification-tap flows for the same message type.
- Confirm each path uses the same routing and unread-state behavior.

Dependency note:

- This is mostly repo-side work; backend changes are only needed if payload shapes must be standardized.

## F-08 - Call payload contract

Files:

- [ios/Runner/AppDelegate.swift](../ios/Runner/AppDelegate.swift)
- [lib/main.dart](../lib/main.dart)

TODOs:

- Document the payload contract for `incoming_call`, `call_terminated`, and `new_message`.
- Harden Flutter-side parsing so unexpected payload shapes do not crash the app.
- Confirm the iOS native PushKit/CallKit path and the Flutter background handler interpret the same event types consistently.
- Add defensive handling for malformed or incomplete payloads.

Verification:

- Send representative call and message payloads and confirm valid events still route correctly.
- Send malformed payloads and confirm the app does not crash.

Dependency note:

- This depends on upstream/server-defined payloads and on the non-Flutter iOS native path.

## Cross-cutting follow-up

Files:

- [docs/firebase_implementation_gap_analysis.md](../docs/firebase_implementation_gap_analysis.md)

TODOs:

- Keep this TODO list aligned with the audit findings if the code changes alter the implementation surface.
- Update the audit document if any remediation is completed or if a finding is reclassified.

Verification:

- Review the audit document after implementation to confirm each finding still reflects the current code.