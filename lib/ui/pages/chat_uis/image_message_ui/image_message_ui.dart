// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:getgabs/ui/pages/chat_uis/base_message_ui.dart';
// import 'dart:ui';
// import 'image_message_ui_controller.dart';

// class ImageMessageUi extends StatelessWidget {
//   final String imageUrl;
//   final bool isSentByMe;
//   final DateTime createdAt;
//   final Size mediaQuery;
//   final double rightMargin;
//   final double leftMargin;

//   ImageMessageUi({
//     required this.imageUrl,
//     required this.isSentByMe,
//     required this.createdAt,
//     required this.mediaQuery,
//     required this.rightMargin,
//     required this.leftMargin,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return BaseMessageUi(
//       isSentByMe: isSentByMe,
//       createdAt: createdAt,
//       mediaQuery: mediaQuery,
//       child: Center(
//         child: GetBuilder<ImageController>(
//           init: ImageController(imageUrl),
//           global: false, // Ensuring a new instance is created
//           builder: (controller) {
//             return CachedNetworkImage(
//               imageUrl: controller.imageUrl,
//               placeholder: (context, url) => _buildBlurredImage(url),
//               errorWidget: (context, url, error) => Icon(Icons.error),
//               fit: BoxFit.cover,
//             );
//           },
//         ),
//       ),
//     );
//   }

//   Widget _buildBlurredImage(String url) {
//     return FutureBuilder(
//       future: _loadImage(url),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.done &&
//             snapshot.hasData) {
//           return ImageFiltered(
//             imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
//             child: Image.memory(
//               snapshot.data as Uint8List,
//               fit: BoxFit.cover,
//               colorBlendMode: BlendMode.darken,
//               color: Colors.black.withOpacity(0.3),
//             ),
//           );
//         } else {
//           return Container(
//             height: 200,
//             color: Colors.grey,
//             child: Center(child: CircularProgressIndicator()),
//           );
//         }
//       },
//     );
//   }

//   Future<Uint8List> _loadImage(String url) async {
//     final response = await NetworkAssetBundle(Uri.parse(url)).load(url);
//     return response.buffer.asUint8List();
//   }
// }

import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:getgabs/ui/pages/chat_uis/base_message_ui.dart';

import '../local_media_preview_screen.dart';
import '../media_preview_screen.dart';

class ImageController extends GetxController {
  final String imageUrl;

  ImageController(this.imageUrl);
}

class ImageMessageUi extends StatelessWidget {
  final String? imageUrl; // Nullable for local image paths
  final File? imageFile; // For local file images
  final bool isSentByMe;
  final DateTime createdAt;
  final Size mediaQuery;
  final double rightMargin;
  final double leftMargin;
  final String deliveryStatus;
  final String caption;

  const ImageMessageUi({super.key, 
    this.imageUrl,
    this.imageFile,
    required this.isSentByMe,
    required this.createdAt,
    required this.mediaQuery,
    required this.rightMargin,
    required this.leftMargin,
    required this.deliveryStatus,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return BaseMessageUi(
      isSentByMe: isSentByMe,
      createdAt: createdAt,
      mediaQuery: mediaQuery,
      deliveryStatus: deliveryStatus,
      child: Center(
        child: GetBuilder<ImageController>(
          init: ImageController(imageUrl ?? ''),
          global: false,
          builder: (controller) {
          /// ---------- LOCAL IMAGE ----------
            if (imageFile != null) {
              print("Loading local image from file: ${imageFile!.path}");
              print("Caption: $caption");
              return _buildImageWithCaption(
                _buildTapToOpenLocalImage(
                  Image.file(imageFile!, fit: BoxFit.cover),
                  imageFile!,
                ),
              );
            }

              print("Captionttt: $caption");
            /// ---------- NETWORK IMAGE ----------
            return _buildImageWithCaption(
              _buildTapToOpenImage(
                CachedNetworkImage(
                  imageUrl: controller.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _buildBlurredImage(url),
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.broken_image),
                ),
              ),
            );
            // if (imageFile != null) {
            //   // For local images
            //   return _buildTapToOpenLocalImage(
            //       Image.file(imageFile!, fit: BoxFit.cover),imageFile!);

            //   // return _buildTapToOpenImage(Image.file(imageFile!, fit: BoxFit.cover));
            // } else {
            //   return _buildImageWithCaption(
            //     _buildTapToOpenImage(
            //       CachedNetworkImage(
            //         imageUrl: controller.imageUrl,
            //         placeholder: (context, url) => _buildBlurredImage(url),
            //         errorWidget: (context, url, error) => const Icon(Icons.error),
            //       ),
            //     ),
            //   );
            //   // For network images
            //   // return _buildImageWidget(CachedNetworkImage(
            //   //   imageUrl: controller.imageUrl,
            //   //   placeholder: (context, url) => _buildBlurredImage(url),
            //   //   errorWidget: (context, url, error) => Icon(Icons.error),
            //   //   fit: BoxFit.cover,
            //   // ));
            // }
          },
        ),
      ),
    );
  }

  /// ================= IMAGE TAP HANDLERS =================
  Widget _buildTapToOpenLocalImage(Widget image,File file) {
    return GestureDetector(
      onTap: () {
        // Navigate to the MediaPreviewScreen when the image is tapped
        Get.to(() => LocalMediaPreviewScreen(
              mediaUrl: file,
              isVideo: false, // Assuming this is always an image
            ));
      },
      child: _buildImageWidget(image),
    );
  }

  Widget _buildTapToOpenImage(Widget image) {
    return GestureDetector(
      onTap: () {
        // Navigate to the MediaPreviewScreen when the image is tapped
        Get.to(() => MediaPreviewScreen(
              mediaUrl: imageUrl ?? '',
              isVideo: false, // Assuming this is always an image
            ));
      },
      child: _buildImageWidget(image),
    );
  }

  /// ================= IMAGE + CAPTION =================
  Widget _buildImageWithCaption(Widget image) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildImageWidget(image),
        if (caption.isNotEmpty) const SizedBox(height: 8.0),
        if (caption.isNotEmpty)
          SelectableText(
            caption,
            enableInteractiveSelection: true,
            // selectionControls: MaterialTextSelectionControls(),
          ),
          // SelectableText(
          //   caption,
          //   style: const TextStyle(
          //     fontSize: 16.0,
          //     fontWeight: FontWeight.bold,
          //     color: Colors.black87,
          //   ),
          // ),
      ],
    );
  }

  /// ================= IMAGE CONTAINER =================
  Widget _buildImageWidget(Widget image) {
    return Container(
      margin: EdgeInsets.only(top: mediaQuery.height * 0.01),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: SizedBox(
          width: mediaQuery.width * 0.6, // Adjust the width as needed
          height: mediaQuery.height * 0.3, // Adjust the height as needed
          child: image,
        ),
      ),
    );
  }

  /// ================= BLURRED PLACEHOLDER =================
  Widget _buildBlurredImage(String url) {
    return FutureBuilder(
      future: _loadImage(url),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          return ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Image.memory(
              snapshot.data as Uint8List,
              fit: BoxFit.cover,
              colorBlendMode: BlendMode.darken,
              color: Colors.black.withOpacity(0.3),
            ),
          );
        } else {
          return Container(
            height: 200,
            color: Colors.grey,
            child: const Center(child: CircularProgressIndicator()),
          );
        }
      },
    );
  }

  Future<Uint8List> _loadImage(String url) async {
    final response = await NetworkAssetBundle(Uri.parse(url)).load(url);
    return response.buffer.asUint8List();
  }
}
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:getgabs/ui/pages/chat_uis/base_message_ui.dart';
// import 'package:getgabs/ui/pages/chat_uis/image_message_ui/image_message_ui_controller.dart';
// class ImageMessageUi extends StatelessWidget {
//   final String imageUrl;
//   final bool isSentByMe;
//   final DateTime createdAt;
//   final Size mediaQuery;
//   final double rightMargin;
//   final double leftMargin;

//   ImageMessageUi({
//     required this.imageUrl,
//     required this.isSentByMe,
//     required this.createdAt,
//     required this.mediaQuery,
//     required this.rightMargin,
//     required this.leftMargin,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return BaseMessageUi(
//       isSentByMe: isSentByMe,
//       createdAt: createdAt,
//       mediaQuery: mediaQuery,
//       child: Center(
//         child: GetBuilder<ImageController>(
//           init: ImageController(imageUrl),
//           global: false, // Ensuring a new instance is created
//           builder: (controller) {
//             return controller.isLoading
//                 ? CircularProgressIndicator() // Show loading indicator while loading
//                 : Image.network(
//                     controller.imageUrl,
//                     fit: BoxFit.cover,
//                     loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
//                       if (loadingProgress == null) {
//                         return child;
//                       } else {
//                         return Center(
//                           child: CircularProgressIndicator(
//                             value: loadingProgress.expectedTotalBytes != null
//                                 ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)
//                                 : null,
//                           ),
//                         );
//                       }
//                     },
//                   );
//           },
//         ),
//       ),
//     );
//   }
// }
