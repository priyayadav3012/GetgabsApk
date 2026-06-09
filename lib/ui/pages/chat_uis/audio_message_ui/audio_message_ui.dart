import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../base_message_ui.dart';

class AudioController extends GetxController {
  final AudioPlayer audioPlayer = AudioPlayer();
  var isPlaying = false.obs;
  var duration = Duration.zero.obs;
  var position = Duration.zero.obs;

  AudioController(String audioUrl) {
    audioPlayer.onDurationChanged.listen((d) {
      duration.value = d;
    });
    audioPlayer.onPositionChanged.listen((p) {
      position.value = p;
    });
    audioPlayer.onPlayerComplete.listen((_) {
      isPlaying.value = false;
    });
  }

  Future<void> togglePlay(String audioUrl) async {
    if (isPlaying.value) {
      await audioPlayer.pause();
    } else {
      await audioPlayer.play(UrlSource(audioUrl));
    }
    isPlaying.toggle();
  }

  @override
  void onClose() {
    audioPlayer.dispose();
    super.onClose();
  }
}

class AudioMessageUi extends StatelessWidget {
  final String audioUrl;
  final bool isSentByMe;
  final DateTime createdAt;
  final Size mediaQuery;
  final double rightMargin;
  final double leftMargin;
  final bool isInTemplate;
  final String deliveryStatus;

  const AudioMessageUi({
    super.key,
    required this.audioUrl,
    required this.isSentByMe,
    required this.createdAt,
    required this.mediaQuery,
    required this.rightMargin,
    required this.leftMargin,
    this.isInTemplate = false,
    required this.deliveryStatus,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AudioController(audioUrl));
 return BaseMessageUi(
        isSentByMe: isSentByMe,
        createdAt: createdAt,
        mediaQuery: mediaQuery,
        isInTemplate: isInTemplate,
        deliveryStatus: deliveryStatus,
        child: Container(
      margin: EdgeInsets.only(
        right: rightMargin,
        left: leftMargin,
        top: mediaQuery.height * 0.01,
      ),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isSentByMe ? Colors.blue[200] : Colors.grey[300],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Obx(() => IconButton(
                icon: Icon(controller.isPlaying.value ? Icons.pause : Icons.play_arrow, size: 30),
                onPressed: () => controller.togglePlay(audioUrl),
              )),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Obx(() {
                  final maxDuration = controller.duration.value.inSeconds.toDouble();
                  final currentPosition = controller.position.value.inSeconds.toDouble();
                  
                  // Ensure max is at least as large as current position, minimum 1.0
                  final safeMax = (maxDuration > currentPosition ? maxDuration : currentPosition).clamp(1.0, double.infinity);
                  final clampedValue = currentPosition.clamp(0.0, safeMax);
                  
                  return Slider(
                    min: 0,
                    max: safeMax,
                    value: clampedValue,
                    onChanged: (value) async {
                      await controller.audioPlayer.seek(Duration(seconds: value.toInt()));
                    },
                  );
                }),
                Obx(() => Text(
                      "${controller.position.value.inMinutes}:${(controller.position.value.inSeconds % 60).toString().padLeft(2, '0')} / "
                      "${controller.duration.value.inMinutes}:${(controller.duration.value.inSeconds % 60).toString().padLeft(2, '0')}"
                    )),
              ],
            ),
          ),
        ],
      ),
    ),
      );
  }
}