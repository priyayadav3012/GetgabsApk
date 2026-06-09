// import 'package:get/get.dart';

// class ImageController extends GetxController {
//   final String imageUrl;
//   bool isLoading = true;

//   ImageController(this.imageUrl);

//   @override
//   void onInit() {
//     super.onInit();
//     // Simulate loading or handle actual loading logic here
//     Future.delayed(Duration(seconds: 1), () {
//       isLoading = false;
//       update();
//     });
//   }
// }
import 'package:get/get.dart';

class ImageController extends GetxController {
  final String imageUrl;

  ImageController(this.imageUrl);
}
