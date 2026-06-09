import 'package:get/get.dart';

import '../controllers/dashboard/dashboard_controller.dart';
import '../controllers/sockets/sockets_controller.dart';

class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(DashboardController());
    // Get.put(SocketsController(), permanent: true);

    Get.put(SocketsController());
    // if (!Get.isRegistered<SocketsController>()) {
    //     Get.put(SocketsController());
    //   } else {
    //     Get.find<SocketsController>().reconnectSocket();
    //   }
  }
}
