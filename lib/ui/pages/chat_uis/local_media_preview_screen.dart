import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class LocalMediaPreviewScreen extends StatefulWidget {
  final File mediaUrl; // URL of the media (image or video)
  final bool isVideo; // Flag to determine if it's a video
  final String? caption; // Optional caption for the image

  const LocalMediaPreviewScreen({
    super.key,
    required this.mediaUrl,
    required this.isVideo,
    this.caption,
  });

  @override
  _MediaPreviewScreenState createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<LocalMediaPreviewScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _controller = VideoPlayerController.file(widget.mediaUrl)
        ..initialize().then((_) {
          setState(() {
            // Ensure the first frame is shown after initialization
          });
        });
      _controller.setLooping(true); // Optional: Loop the video
      _controller.play(); // Play the video automatically
    }
  }

  @override
  void dispose() {
    if (widget.isVideo) {
      _controller.dispose(); // Dispose of the controller when done
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isVideo ? 'Video Preview' : 'Image Preview'),
        backgroundColor: Colors.white,
        // actions: [
        //   IconButton(
        //     icon: Icon(Icons.download),
        //     onPressed: () {
        //       // Handle download action if needed
        //     },
        //   ),
        // ],
      ),
      backgroundColor: Colors.black,
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Container(
                  child: widget.isVideo
                      ? AspectRatio(
                          aspectRatio: _controller.value.aspectRatio,
                          child: VideoPlayer(_controller),
                        )
                      : Image.file(
                          widget.mediaUrl,
                          fit: BoxFit.cover,
                          // loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                          //   if (loadingProgress == null) return child;
                          //   return Center(
                          //     child: CircularProgressIndicator(
                          //       value: loadingProgress.expectedTotalBytes != null
                          //           ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)
                          //           : null,
                          //     ),
                          //   );
                          // },
                          errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) {
                            return const Center(child: Text('Error loading image', style: TextStyle(color: Colors.white)));
                          },
                        ),
                ),
              ),
            ),
          ),
          if (widget.isVideo) // Only show progress bar if it's a video
            Column(
              children: [
                VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  colors: const VideoProgressColors(
                    playedColor: Colors.red,
                    bufferedColor: Colors.white,
                    backgroundColor: Colors.grey,
                  ),
                ),
                const SizedBox(height: 10), // Spacer between the progress bar and caption
              ],
            ),
          if (widget.caption != null && widget.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                widget.caption!,
                style: const TextStyle(color: Colors.white, fontSize: 16.0, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
      floatingActionButton: widget.isVideo
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying ? _controller.pause() : _controller.play();
                });
              },
              child: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
            )
          : null, // No button for image preview
    );
  }
}
