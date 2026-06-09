import 'dart:io'; // For File
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';

class VideoController extends GetxController {
  late VideoPlayerController videoPlayerController;
  var isInitialized = false;
  var isPlaying = false;

  final String videoUrl;
  final bool isLocal;

  VideoController(this.videoUrl, {this.isLocal = false});

  @override
  void onInit() {
    super.onInit();
    if (isLocal) {
      videoPlayerController = VideoPlayerController.file(File(videoUrl))
        ..initialize().then((_) {
          isInitialized = true;
          update();
        });
    } else {
      videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
        ..initialize().then((_) {
          isInitialized = true;
          update();
        });
    }
  }

  double get aspectRatio => videoPlayerController.value.aspectRatio;

  void togglePlay() {
    if (isPlaying) {
      videoPlayerController.pause();
    } else {
      videoPlayerController.play();
    }
    isPlaying = !isPlaying;
    update();
  }

  @override
  void onClose() {
    videoPlayerController.dispose();
    super.onClose();
  }
}


// import 'package:get/get.dart';
// import 'package:video_player/video_player.dart';

// class VideoController extends GetxController {
//   late VideoPlayerController videoPlayerController;
//   var isInitialized = false;
//   var isPlaying = false;

//   final String videoUrl;

//   VideoController(this.videoUrl);

//   @override
//   void onInit() {
//     super.onInit();
//     videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
//       ..initialize().then((_) {
//         isInitialized = true;
//         update();
//       });
//   }

//   double get aspectRatio => videoPlayerController.value.aspectRatio;

//   void togglePlay() {
//     if (isPlaying) {
//       videoPlayerController.pause();
//     } else {
//       videoPlayerController.play();
//     }
//     isPlaying = !isPlaying;
//     update();
//   }

//   @override
//   void onClose() {
//     videoPlayerController.dispose();
//     super.onClose();
//   }
// }

