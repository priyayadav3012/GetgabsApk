# F-07 Change Log

Date: 2026-06-10

Summary:
- Consolidated socket-driven chat notification display into `NotificationService`.
- Removed the socket controller's duplicate local-notification initialization and tap-handling path.
- Kept socket foreground updates and unread-state updates intact.

Files changed:
- `lib/domain/services/notifications_service/notification_service.dart`
- `lib/domain/controllers/sockets/sockets_controller.dart`

Validation:
- `get_errors` on the touched files returned no errors.
