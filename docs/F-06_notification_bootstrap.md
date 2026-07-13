# F-06 Notification Bootstrap

Status: implemented

Changed files:
- [lib/domain/services/notifications_service/notification_service.dart](../lib/domain/services/notifications_service/notification_service.dart)
- [lib/domain/controllers/dashboard/dashboard_controller.dart](../lib/domain/controllers/dashboard/dashboard_controller.dart)

Notes:
- Local notification initialization now runs once without requiring a `RemoteMessage` argument.
- Tap routing uses the notification payload so initialization can happen before the first push arrives.
- Dashboard startup now initializes local notifications before registering the remaining message listeners.

Verification:
- Analyze the touched notification files.
- Launch the app and confirm local notification taps are registered after startup.