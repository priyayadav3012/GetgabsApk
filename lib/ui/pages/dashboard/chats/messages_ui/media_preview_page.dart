import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:get_thumbnail_video/video_thumbnail.dart';

// class MediaPreviewPage extends StatelessWidget {
//   final List<File> files;
//   final bool isVideo;
//   final bool isDocument;
//   final Function(int, String) onSend;

//   const MediaPreviewPage({
//     super.key,
//     required this.files,
//     required this.isVideo,
//     required this.isDocument,
//     required this.onSend,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: SafeArea(
//         child: Column(
//           children: [
//             Expanded(
//               child: ListView.builder(
//                 scrollDirection: Axis.horizontal,
//                 itemCount: files.length,
//                 itemBuilder: (context, index) {
//                   final file = files[index];
//                   return _buildMediaPreview(file, index, context);
//                 },
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildMediaPreview(File file, int index, context) {
//     final TextEditingController captionController = TextEditingController();

//     return Column(
//       children: [

//         if (isVideo)
//           VideoPlayerWidget(file: file)
//         else if (isDocument)
//           _buildDocumentPreview(file)
//         else
//           Container(
//               height: MediaQuery.of(context).size.height * 0.8,
//               child: Image.file(file)),

//               SizedBox(width: 383,)
//         // Padding(
//         //   padding: const EdgeInsets.all(8.0),
//         //   child: Row(
//         //     children: [
//         //       Expanded(
//         //         child: TextField(
//         //           controller: captionController,
//         //           decoration: const InputDecoration(
//         //             hintText: 'Add a caption...',
//         //             border: OutlineInputBorder(),
//         //           ),
//         //         ),
//         //       ),
//         //       IconButton(
//         //         icon: const Icon(Icons.send),
//         //         onPressed: () {
//         //           onSend(index, captionController.text);
//         //           Get.back();
//         //         },
//         //       ),
//         //     ],
//         //   ),
//         // ),
//         //const Divider(), // Add a divider between media previews
//       ],
//     );
//   }

//   Widget _buildDocumentPreview(File file) {
//     String fileName = path.basename(file.path);
//     return Container(
//       padding: const EdgeInsets.all(16.0),
//       margin: const EdgeInsets.only(top: 16.0),
//       decoration: BoxDecoration(
//         color: Colors.grey[200],
//         borderRadius: BorderRadius.circular(8.0),
//       ),
//       child: Column(
//         children: [
//           const Icon(Icons.insert_drive_file, size: 100, color: Colors.blue),
//           const SizedBox(height: 16),
//           Text(
//             fileName,
//             style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//             overflow: TextOverflow.ellipsis,
//             maxLines: 2,
//           ),
//           const SizedBox(height: 8),
//           const Text(
//             'Tap send to share the document',
//             style: TextStyle(fontSize: 14, color: Colors.black54),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class VideoPlayerWidget extends StatefulWidget {
//   final File file;

//   const VideoPlayerWidget({super.key, required this.file});

//   @override
//   _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
// }

// class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
//   late VideoPlayerController _controller;
//   late Future<void> _initializeVideoPlayerFuture;
//   bool _isPlaying = false;

//   @override
//   void initState() {
//     super.initState();
//     _controller = VideoPlayerController.file(widget.file);
//     _initializeVideoPlayerFuture = _controller.initialize().then((_) {
//       setState(() {
//         _isPlaying = _controller.value.isPlaying;
//       });
//     });
//     _controller.setLooping(true);
//     _controller.addListener(() {
//       setState(() {
//         _isPlaying = _controller.value.isPlaying;
//       });
//     });
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   void _togglePlayPause() {
//     setState(() {
//       if (_isPlaying) {
//         _controller.pause();
//       } else {
//         _controller.play();
//       }
//       _isPlaying = !_isPlaying;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       alignment: Alignment.center,
//       children: [
//         FutureBuilder<void>(
//           future: _initializeVideoPlayerFuture,
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.done) {
//               return AspectRatio(
//                 aspectRatio: _controller.value.aspectRatio,
//                 child: VideoPlayer(_controller),
//               );
//             } else {
//               return const Center(child: CircularProgressIndicator());
//             }
//           },
//         ),
//         if (_controller.value.isInitialized)
//           Positioned(
//             bottom: 0,
//             left: 0,
//             right: 0,
//             child: VideoProgressIndicator(
//               _controller,
//               allowScrubbing: true,
//               colors: const VideoProgressColors(
//                 playedColor: Colors.green,
//                 bufferedColor: Colors.grey,
//                 backgroundColor: Colors.black,
//               ),
//             ),
//           ),
//         if (_controller.value.isInitialized)
//           Center(
//             child: IconButton(
//               icon: Icon(
//                 _isPlaying ? Icons.pause : Icons.play_arrow,
//                 color: Colors.white,
//                 size: 50.0,
//               ),
//               onPressed: _togglePlayPause,
//             ),
//           ),
//       ],
//     );
//   }
// }

class MediaPreviewPage extends StatelessWidget {
  final List<File> files;
  final bool isDocument;
  final Function(String) onSend;

  const MediaPreviewPage({super.key, 
    required this.files,
    required this.isDocument,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final TextEditingController captionController = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('Media Preview')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: files.length == 1
                  ? _buildSinglePreview(context)  // Show single item in full screen
                  : _buildGridPreviews(context),   // Show multiple items in grid
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: files.length == 1
                  ? Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: captionController,
                            decoration: const InputDecoration(
                              hintText: 'Add a caption...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: () {
                            onSend(captionController.text);
                            Get.back();
                          },
                        ),
                      ],
                    )
                  : Center(
                      child: ElevatedButton(
                        onPressed: () {
                          onSend(""); // Send without caption for multiple items
                          Get.back();
                        },
                        child: const Text('Send'),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSinglePreview(BuildContext context) {
    final file = files.first;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: _isVideoFile(file)
          ? VideoPlayerWidget(file: file)
          : isDocument
              ? _buildDocumentPreview(file)
              : Image.file(file, fit: BoxFit.cover, width: double.infinity),
    );
  }

  Widget _buildGridPreview(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,  // Display 2 items per row
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.0),
            color: Colors.grey[200],
          ),
          child: _isVideoFile(file)
              ?
              VideoPlayerWidget(file: file)
// generateVideoThumbnail(file)
              : isDocument
                  ? _buildDocumentPreview(file)
                  : Image.file(file, fit: BoxFit.cover),
        );
      },
    );
  }
Widget _buildGridPreviews(BuildContext context) {
  return GridView.builder(
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,  // Display 2 items per row
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.8,
    ),
    itemCount: files.length,
    itemBuilder: (context, index) {
      final file = files[index];
      if (_isVideoFile(file)) {
        print("Attempting to generate thumbnail for: ${file.path}");
        
        return FutureBuilder<Uint8List?>(
          future: VideoThumbnail.thumbnailData(
            video: file.path,
            imageFormat: ImageFormat.JPEG,
            maxWidth: 64,   // Try a smaller width
            quality: 100,    // Try a lower quality
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.hasData) {
                final uint8list = snapshot.data!;
                return GestureDetector(
                  onTap: () {
                    Get.to(() => VideoPlayerWidget(file: file));
                  },
                  child: Image.memory(
                    uint8list,
                    fit: BoxFit.cover,
                  ),
                );
              } else {
                print("Error: Failed to load thumbnail for ${file.path}");
                return const Center(child: Text("Failed to load thumbnail"));
              }
            } else if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else {
              print("Unexpected error occurred.");
              return const Center(child: Text("Error loading thumbnail"));
            }
          },
        );
      } else {
        return Image.file(file, fit: BoxFit.cover);
      }
    },
  );
}


//  Future<Widget>  generateVideoThumbnail(File file) async{
//   final uint8list= await VideoThumbnail.thumbnailData(
//   video: file.path,
//   imageFormat: ImageFormat.JPEG,
//   maxWidth: 128, // specify the width of the thumbnail, let the height auto-scaled to keep the source aspect ratio
//   quality: 25,
// );
//   }

  bool _isVideoFile(File file) {
    final extension = path.extension(file.path).toLowerCase();
    return extension == '.mp4' || extension == '.mov' || extension == '.avi';
  }

  Widget _buildDocumentPreview(File file) {
    String fileName = path.basename(file.path);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.insert_drive_file, size: 50, color: Colors.blue),
        const SizedBox(height: 8),
        Text(
          fileName,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final File file;

  const VideoPlayerWidget({super.key, required this.file});

  @override
  _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file);
    _initializeVideoPlayerFuture = _controller.initialize();
    _controller.setLooping(true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeVideoPlayerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
              IconButton(
                icon: Icon(
                  _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 50.0,
                ),
                onPressed: () {
                  setState(() {
                    _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play();
                  });
                },
              ),
            ],
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}


// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:video_player/video_player.dart';
// import 'dart:io';
// import 'package:path/path.dart' as path;

// class MediaPreviewPage extends StatelessWidget {
//   final File file;
//   final bool isVideo;
//   final Function(String) onSend;
//   final bool isDocument;

//   const MediaPreviewPage({super.key, required this.file, required this.isVideo, required this.onSend, required this.isDocument, });

//   @override
//   Widget build(BuildContext context) {
//     final TextEditingController captionController = TextEditingController();

//     return Scaffold(
//       body: SafeArea(
//         child: Stack(
//           children: [
//             SingleChildScrollView(
//               child: Column(
//                 children: [
//                   if (isVideo)
//                     VideoPlayerWidget(file: file)  // Implement VideoPlayerWidget for video preview
//                   else if(isDocument)
//                    _buildDocumentPreview(file) 
//                    else
//                     Image.file(file),
//                   Padding(
//                     padding: const EdgeInsets.all(8.0),
//                     child: Row(
//                       children: [
//                         Expanded(
//                           child: TextField(
//                             controller: captionController,
//                             decoration: const InputDecoration(
//                               hintText: 'Add a caption...',
//                               border: OutlineInputBorder(),
//                             ),
//                           ),
//                         ),
//                         IconButton(
//                           icon: const Icon(Icons.send),
//                           onPressed: () {
//                             onSend(captionController.text);
//                             Get.back();
//                           },
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
// Widget _buildDocumentPreview(File file) {
//     String fileName = path.basename(file.path);
//     return Container(
      
//       padding: const EdgeInsets.all(16.0),
//       margin: const EdgeInsets.only(top: 16.0),
//       decoration: BoxDecoration(
//         color: Colors.grey[200],
//         borderRadius: BorderRadius.circular(8.0),
//       ),
//       child: Column(
//         children: [
//           const Icon(Icons.insert_drive_file, size: 100, color: Colors.blue),
//           const SizedBox(height: 16),
//           Text(
//             fileName,
//             style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//             overflow: TextOverflow.ellipsis,
//             maxLines: 2,
//           ),
//           const SizedBox(height: 8),
//           const Text(
//             'Tap send to share the document',
//             style: TextStyle(fontSize: 14, color: Colors.black54),
//           ),
//         ],
//       ),
//     );
//   }

// class VideoPlayerWidget extends StatefulWidget {
//   final File file;

//   const VideoPlayerWidget({super.key, required this.file});

//   @override
//   _VideoPlayerWidgetState createState() => _VideoPlayerWidgetState();
// }

// class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
//   late VideoPlayerController _controller;
//   late Future<void> _initializeVideoPlayerFuture;
//   bool _isPlaying = false;

//   @override
//   void initState() {
//     super.initState();
//     _controller = VideoPlayerController.file(widget.file);
//     _initializeVideoPlayerFuture = _controller.initialize().then((_) {
//       setState(() {
//         _isPlaying = _controller.value.isPlaying;
//       });
//     });
//     _controller.setLooping(true);
//     _controller.addListener(() {
//       setState(() {
//         _isPlaying = _controller.value.isPlaying;
//       });
//     });
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   void _togglePlayPause() {
//     setState(() {
//       if (_isPlaying) {
//         _controller.pause();
//       } else {
//         _controller.play();
//       }
//       _isPlaying = !_isPlaying;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       alignment: Alignment.center,
//       children: [
//         FutureBuilder<void>(
//           future: _initializeVideoPlayerFuture,
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.done) {
//               return AspectRatio(
//                 aspectRatio: _controller.value.aspectRatio,
//                 child: VideoPlayer(_controller),
//               );
//             } else {
//               return const Center(child: CircularProgressIndicator());
//             }
//           },
//         ),
//         if (_controller.value.isInitialized) 
//           Positioned(
//             bottom: 0,
//             left: 0,
//             right: 0,
//             child: VideoProgressIndicator(
//               _controller,
//               allowScrubbing: true,
//               colors: const VideoProgressColors(
//                 playedColor: Colors.green,
//                 bufferedColor: Colors.grey,
//                 backgroundColor: Colors.black,
//               ),
//             ),
//           ),
//         if (_controller.value.isInitialized)
//           Center(
//             child: IconButton(
//               icon: Icon(
//                 _isPlaying ? Icons.pause : Icons.play_arrow,
//                 color: Colors.white,
//                 size: 50.0,
//               ),
//               onPressed: _togglePlayPause,
//             ),
//           ),
//       ],
//     );
//   }
// }


