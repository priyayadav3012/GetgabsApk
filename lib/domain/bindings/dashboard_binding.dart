import 'package:get/get.dart';

import '../controllers/dashboard/dashboard_controller.dart';
// import '../controllers/sockets/sockets_controller.dart'; // retired, see below

class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(DashboardController());

    // Socket.IO retired for chat — new-message delivery, live status updates,
    // and read-receipt push now go through FCM data messages instead (see
    // NotificationService.firebaseInit() and chat_payload_parser.dart).
    // Get.put(SocketsController());
  }
}
