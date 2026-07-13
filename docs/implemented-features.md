# Implemented Features

This document summarizes the features that are currently implemented in the Flutter codebase.

## 1. App Bootstrap and Session Entry

- The app starts from a splash screen and uses GetX routing for navigation.
- Firebase is initialized at startup and Firebase Cloud Messaging is configured.
- The splash flow checks persisted local storage to decide whether to route to the dashboard or the login screen.
- A device token is fetched during startup for push notification support.

Relevant files:
- [lib/main.dart](../lib/main.dart)
- [lib/ui/pages/splash_screen/splash_screen.dart](../lib/ui/pages/splash_screen/splash_screen.dart)
- [lib/domain/controllers/splash_screen/splash_screen_controller.dart](../lib/domain/controllers/splash_screen/splash_screen_controller.dart)

## 2. Authentication and Onboarding

- A branded email login screen is implemented with animated UI elements.
- A start screen exists as an onboarding entry point that routes users to login.
- Route definitions also include placeholders for mobile login, signup, forgot password, and verification screens, but those are not currently wired in the active route list.

Relevant files:
- [lib/ui/pages/auth/login_with_email/login_with_email.dart](../lib/ui/pages/auth/login_with_email/login_with_email.dart)
- [lib/ui/pages/auth/start_page/start_page.dart](../lib/ui/pages/auth/start_page/start_page.dart)
- [lib/routes/app_route.dart](../lib/routes/app_route.dart)
- [lib/routes/app_page.dart](../lib/routes/app_page.dart)

## 3. Dashboard Shell

- The main authenticated area is a two-tab dashboard.
- Bottom navigation switches between Chats and More.
- The dashboard initializes the call listener when it is built.

Relevant files:
- [lib/ui/pages/dashboard/dashboard.dart](../lib/ui/pages/dashboard/dashboard.dart)
- [lib/domain/controllers/dashboard/dashboard_controller.dart](../lib/domain/controllers/dashboard/dashboard_controller.dart)

## 4. Chat Inbox Features

- The Chats tab includes a search field for filtering conversations.
- The inbox supports two chat buckets: active chats and rolling-over chats.
- Both lists support pull-to-refresh and loading states.
- Empty states are implemented with refresh actions.

Relevant files:
- [lib/ui/pages/dashboard/chats/chats.dart](../lib/ui/pages/dashboard/chats/chats.dart)
- [lib/ui/pages/dashboard/chats/active_chats/active_chats.dart](../lib/ui/pages/dashboard/chats/active_chats/active_chats.dart)
- [lib/ui/pages/dashboard/chats/rolling_over_chats.dart/rolling_over_chats.dart](../lib/ui/pages/dashboard/chats/rolling_over_chats.dart/rolling_over_chats.dart)
- [lib/ui/pages/dashboard/chats/active_chats/active_chat_list_tile.dart](../lib/ui/pages/dashboard/chats/active_chats/active_chat_list_tile.dart)
- [lib/ui/pages/dashboard/chats/rolling_over_chats.dart/rolling_over_list_tile.dart](../lib/ui/pages/dashboard/chats/rolling_over_chats.dart/rolling_over_list_tile.dart)

## 5. Conversation View and Messaging

- The conversation screen groups messages by date and renders a threaded chat timeline.
- It supports AI pause/resume controls from the message header.
- It exposes a call action for starting WhatsApp-style voice calling.
- The bottom composer area is implemented for sending new messages.

Relevant files:
- [lib/ui/pages/dashboard/chats/messages_ui/messages_page.dart](../lib/ui/pages/dashboard/chats/messages_ui/messages_page.dart)
- [lib/domain/controllers/dashboard/messages_page/messages_page_controller.dart](../lib/domain/controllers/dashboard/messages_page/messages_page_controller.dart)
- [lib/ui/pages/dashboard/chats/messages_ui/whatsapp_calling_screen.dart](../lib/ui/pages/dashboard/chats/messages_ui/whatsapp_calling_screen.dart)

## 6. Message Type Rendering

The app contains dedicated UI components for multiple message types:

- Text messages
- Image messages
- Audio messages
- Video messages
- Document messages
- Contact messages
- Location messages
- Template messages
- Reply messages
- Button messages
- Interactive messages
- Order messages

Relevant files:
- [lib/ui/pages/chat_uis/text_message_ui.dart](../lib/ui/pages/chat_uis/text_message_ui.dart)
- [lib/ui/pages/chat_uis/image_message_ui/image_message_ui.dart](../lib/ui/pages/chat_uis/image_message_ui/image_message_ui.dart)
- [lib/ui/pages/chat_uis/audio_message_ui/audio_message_ui.dart](../lib/ui/pages/chat_uis/audio_message_ui/audio_message_ui.dart)
- [lib/ui/pages/chat_uis/vide_message_uis/video_message_ui.dart](../lib/ui/pages/chat_uis/vide_message_uis/video_message_ui.dart)
- [lib/ui/pages/chat_uis/document_message/document_message_ui.dart](../lib/ui/pages/chat_uis/document_message/document_message_ui.dart)
- [lib/ui/pages/chat_uis/contact_message_ui/contact_message_ui.dart](../lib/ui/pages/chat_uis/contact_message_ui/contact_message_ui.dart)
- [lib/ui/pages/chat_uis/location_message_ui/location_message_ui.dart](../lib/ui/pages/chat_uis/location_message_ui/location_message_ui.dart)
- [lib/ui/pages/chat_uis/templete_message_uis/templete_message_ui.dart](../lib/ui/pages/chat_uis/templete_message_uis/templete_message_ui.dart)
- [lib/ui/pages/chat_uis/reply_message/reply_message_ui.dart](../lib/ui/pages/chat_uis/reply_message/reply_message_ui.dart)
- [lib/ui/pages/chat_uis/button_message_ui.dart](../lib/ui/pages/chat_uis/button_message_ui.dart)
- [lib/ui/pages/chat_uis/interactive_message/interactive_message_ui.dart](../lib/ui/pages/chat_uis/interactive_message/interactive_message_ui.dart)
- [lib/ui/pages/chat_uis/order_message/order_message_ui.dart](../lib/ui/pages/chat_uis/order_message/order_message_ui.dart)

## 7. Media Preview and File Handling

- Remote media can be previewed before download.
- Local media preview is supported for files already on device.
- The app can download files, save them locally, open them, and share them on supported platforms.

Relevant files:
- [lib/ui/pages/chat_uis/media_preview_screen.dart](../lib/ui/pages/chat_uis/media_preview_screen.dart)
- [lib/ui/pages/chat_uis/local_media_preview_screen.dart](../lib/ui/pages/chat_uis/local_media_preview_screen.dart)
- [lib/ui/pages/dashboard/chats/messages_ui/media_preview_page.dart](../lib/ui/pages/dashboard/chats/messages_ui/media_preview_page.dart)

## 8. WhatsApp-Style Calling

- The codebase includes a full calling flow with foreground and background call handling.
- Incoming calls use CallKit on iOS and customized incoming call notifications on Android.
- The app handles incoming, outgoing, answered, declined, busy, ended, and terminated call states.
- Background FCM handlers persist pending call details and clear them after termination.

Relevant files:
- [lib/domain/services/whtasapp_calling_service.dart](../lib/domain/services/whtasapp_calling_service.dart)
- [lib/ui/pages/dashboard/chats/messages_ui/whatsapp_calling_screen.dart](../lib/ui/pages/dashboard/chats/messages_ui/whatsapp_calling_screen.dart)
- [lib/main.dart](../lib/main.dart)

## 9. Profile and Account Management

- A profile page displays user name, email, phone number, and business role.
- The More screen contains logout functionality.
- Logout clears local user data, disconnects sockets, unsubscribes from notifications, and deletes the Firebase token.

Relevant files:
- [lib/ui/pages/dashboard/more/profile/profile.dart](../lib/ui/pages/dashboard/more/profile/profile.dart)
- [lib/ui/pages/dashboard/more/more_screen.dart](../lib/ui/pages/dashboard/more/more_screen.dart)
- [lib/domain/controllers/more/ProfileController.dart](../lib/domain/controllers/more/ProfileController.dart)
- [lib/domain/controllers/more_screen/more_screen_controller.dart](../lib/domain/controllers/more_screen/more_screen_controller.dart)
- [lib/domain/services/remote_services/more_screen_service.dart](../lib/domain/services/remote_services/more_screen_service.dart)

## 10. Operator Assignment

- The app includes an operator assignment screen with search and selection state.
- Users can pick an operator and trigger an assign action from the UI.

Relevant files:
- [lib/ui/pages/dashboard/chats/rolling_over_chats.dart/rolling_message_ui/assign_opreator.dart](../lib/ui/pages/dashboard/chats/rolling_over_chats.dart/rolling_message_ui/assign_opreator.dart)

## 11. Notifications and Background Refresh Hooks

- A notification screen exists with a visible list layout.
- Background FCM handling marks the app for message refresh when a new message arrives.
- Notification-related service code is present for topic subscription management and server-key handling.

Relevant files:
- [lib/ui/pages/dashboard/notification/notification.dart](../lib/ui/pages/dashboard/notification/notification.dart)
- [lib/domain/services/notifications_service/notification_service.dart](../lib/domain/services/notifications_service/notification_service.dart)
- [lib/domain/services/notifications_service/get_server_key.dart](../lib/domain/services/notifications_service/get_server_key.dart)

## 12. Notes on Coverage

- This documentation is based on the implemented screens, controllers, and services currently present in the repository.
- Some routes and legacy screens appear in the codebase but are not active in the current route table.
- The notification screen is implemented as a basic list UI and may still be a placeholder compared with the rest of the app.
