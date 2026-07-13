import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:getgabs/ui/pages/chat_uis/vide_message_uis/video_message_ui_controller.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import '../base_message_ui.dart';
import '../media_preview_screen.dart';

/*






*/
class VideoMessageUi extends StatelessWidget {
  final String videoUrl;
  final bool isSentByMe;
  final DateTime createdAt;
  final Size mediaQuery;
  final double rightMargin;
  final double leftMargin;
  final bool isInTemplate; // New parameter to check if in template
  final bool isLocal;
  final String deliveryStatus;
  const VideoMessageUi({
    super.key,
    required this.videoUrl,
    required this.isSentByMe,
    required this.createdAt,
    required this.mediaQuery,
    required this.rightMargin,
    required this.leftMargin,
    this.isInTemplate = false,
    this.isLocal = false,
    required this.deliveryStatus,
  });

  @override
  Widget build(BuildContext context) {
    if (isInTemplate) {
      return Center(
        child: GestureDetector(
          onTap: () {
            Get.to(() => MediaPreviewScreen(
              mediaUrl: videoUrl,
              isVideo: true,
            ));
          },
          child: Container(
            width: mediaQuery.width * 0.8,
            height: mediaQuery.height * 0.3,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.videocam,
                      size: 64,
                      color: Colors.white70,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(16),
                  child: const Icon(
                    Icons.play_circle_outline,
                    color: Colors.white,
                    size: 56,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      return BaseMessageUi(
        isSentByMe: isSentByMe,
        createdAt: createdAt,
        mediaQuery: mediaQuery,
        isInTemplate: isInTemplate,
        deliveryStatus: deliveryStatus,
        child: Center(
          child: GestureDetector(
            onTap: () {
              Get.to(() => MediaPreviewScreen(
                mediaUrl: videoUrl,
                isVideo: true,
              ));
            },
            child: _buildVideoThumbnail(),
          ),
        ),
      );
    }
  }

  Widget _buildVideoThumbnail() {
    return Container(
      margin: EdgeInsets.only(top: mediaQuery.height * 0.01),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Container(
          width: mediaQuery.width * 0.6,
          height: mediaQuery.height * 0.25,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: FutureBuilder<String?>(
            future: _generateThumbnail(),
            builder: (context, snapshot) {
              return Stack(
                alignment: Alignment.center,
                fit: StackFit.expand,
                children: [
                  if (snapshot.connectionState == ConnectionState.done &&
                      snapshot.hasData &&
                      snapshot.data != null)
                    Image.file(
                      File(snapshot.data!),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildPlaceholder(),
                    )
                  else if (snapshot.connectionState == ConnectionState.waiting)
                    Container(
                      color: Colors.grey.shade900,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  else
                    _buildPlaceholder(),
                  // Play button overlay
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(20),
                    child: const Icon(
                      Icons.play_circle_outline,
                      color: Colors.white,
                      size: 72,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: const Center(
        child: Icon(
          Icons.videocam,
          size: 64,
          color: Colors.white70,
        ),
      ),
    );
  }

  Future<String?> _generateThumbnail() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbnail = await VideoThumbnail.thumbnailFile(
        video: videoUrl,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.PNG,
        maxHeight: 300, // Smaller for memory optimization
        quality: 60, // Lower quality for better performance
      );
      return thumbnail.path;
    } catch (e) {
      print('Error generating thumbnail: $e');
      return null;
    }
  }

  Widget _buildVideoWidget(VideoController controller) {
    return Container(
      margin: EdgeInsets.only(top: mediaQuery.height * 0.01),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: SizedBox(
            width:
                mediaQuery.width * 0.6, // Adjusted width to be slightly smaller

            height: mediaQuery.height *
                0.25, // Adjusted height to be slightly smaller

            child: AspectRatio(
              aspectRatio: controller.aspectRatio,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: <Widget>[
                  // VideoPlayer(controller.videoPlayerController),
                  VideoPlayer(controller.videoPlayerController),
                  VideoProgressIndicator(
                    controller.videoPlayerController,
                    allowScrubbing: true,
                  ),
                  IconButton(
                      onPressed: () {
                        Get.to(() => MediaPreviewScreen(
                              mediaUrl: videoUrl,
                              isVideo: true,
                            ));
                      },
                      icon: const Center(
                          child: Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 50,
                      )))
                  // _ControlsOverlay(controller: controller),
                ],
              ),
            )),
      ),
    );
  }
}

class _ControlsOverlay extends StatelessWidget {
  final VideoController controller;

  const _ControlsOverlay({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        GestureDetector(
          onTap: () {
            controller.togglePlay();
          },
          child: Center(
            child: Icon(
              controller.isPlaying ? Icons.pause : Icons.play_arrow,
              size: 64.0,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
