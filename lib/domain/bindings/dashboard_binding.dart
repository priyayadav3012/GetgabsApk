import 'package:get/get.dart';

import '../controllers/dashboard/dashboard_controller.dart';
import '../controllers/sockets/sockets_controller.dart';

class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(DashboardController());

    // Re-enabled as an ADDITIVE fast-path only: while a chat is open and the
    // app is foreground, the socket delivers new messages/typing state into
    // that chat near-instantly. FCM (NotificationService.firebaseInit() /
    // the background handler in main.dart) remains completely unchanged and
    // is still the sole path for background/killed-app notifications and
    // for any chat that ISN'T currently open — see the scoping comment on
    // SocketsController's 'chatdata' listener for why that split keeps this
    // safe to run alongside FCM without double-counting unread badges or
    // duplicate notifications.
    Get.put(SocketsController());
  }
}
