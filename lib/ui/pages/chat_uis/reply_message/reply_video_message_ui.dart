import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:getgabs/ui/pages/chat_uis/media_preview_screen.dart';
import 'package:getgabs/ui/pages/chat_uis/reply_message/reply_base_message_ui.dart';
import 'package:getgabs/ui/pages/chat_uis/vide_message_uis/video_message_ui_controller.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

class ReplyVideoMessageUi extends StatelessWidget {
  final String videoUrl;

  final Size mediaQuery;

  final bool isInTemplate; // New parameter to check if in template
  final bool isLocal;

  const ReplyVideoMessageUi({
    super.key,
    required this.videoUrl,
    required this.mediaQuery,
    this.isInTemplate = false,
    this.isLocal = false,
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
            height: mediaQuery.height * 0.2,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
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
                              _buildPlaceholder(48),
                        )
                      else if (snapshot.connectionState ==
                          ConnectionState.waiting)
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
                        _buildPlaceholder(48),
                      const Icon(
                        Icons.play_circle_filled,
                        color: Colors.white,
                        size: 40,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    } else {
      return ReplyBaseMessageUi(
        mediaQuery: mediaQuery,
        isInTemplate: isInTemplate,
        child: Center(
          child: GestureDetector(
            onTap: () {
              Get.to(() => MediaPreviewScreen(
                mediaUrl: videoUrl,
                isVideo: true,
              ));
            },
            child: Container(
              width: mediaQuery.width * 0.2,
              height: mediaQuery.height * 0.05,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
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
                                _buildPlaceholder(16),
                          )
                        else if (snapshot.connectionState ==
                            ConnectionState.waiting)
                          Container(
                            color: Colors.grey.shade900,
                            child: const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          )
                        else
                          _buildPlaceholder(16),
                        const Icon(
                          Icons.play_circle_filled,
                          color: Colors.white,
                          size: 24,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  Widget _buildPlaceholder(double iconSize) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Center(
        child: Icon(
          Icons.videocam,
          size: iconSize,
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
        maxHeight: 200, // Smaller for reply thumbnails - memory optimized
        quality: 50, // Lower quality for better performance
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
                mediaQuery.width * 0.2, // Adjusted width to be slightly smaller

            height: mediaQuery.height *
                0.05, // Adjusted height to be slightly smaller

            child: AspectRatio(
              aspectRatio: controller.aspectRatio,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: <Widget>[
                  // VideoPlayer(controller.videoPlayerController),
                  VideoPlayer(controller.videoPlayerController),
                  // VideoProgressIndicator(
                  //   controller.videoPlayerController,
                  //   allowScrubbing: true,
                  // ),
                ],
              ),
            )),
      ),
    );
  }
}
