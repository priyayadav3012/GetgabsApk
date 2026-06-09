import 'dart:io';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getgabs/ui/themes/themes.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:path/path.dart' as filedirectory; // Import the 'path' package

class MediaPreviewScreen extends StatefulWidget {
  final String mediaUrl; // URL of the media (image or video)
  final bool isVideo; // Flag to determine if it's a video
  final String? caption; // Optional caption for the image

  const MediaPreviewScreen({
    super.key,
    required this.mediaUrl,
    required this.isVideo,
    this.caption,
  });

  @override
  _MediaPreviewScreenState createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  late VideoPlayerController _controller;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.mediaUrl))
        ..initialize().then((_) {
          setState(() {
            // Ensure the first frame is shown after initialization
          });
        });
      _controller.setLooping(false); // Optional: Loop the video
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

// Cross-platform file download function
  Future<void> downloadFileCrossPlatform(String mediaUrl, {String? folderName}) async {
    EasyLoading.show(status: "Downloading...");
    try {
      String fileName = mediaUrl.split('/').last;

      Directory directory;

      if (Platform.isAndroid) {
        // Android: Downloads folder
        directory = Directory("/storage/emulated/0/Download");
        if (folderName != null) {
          directory = Directory("${directory.path}/$folderName");
        }
      } else {
        // iOS: App documents directory
        directory = await getApplicationDocumentsDirectory();
        if (folderName != null) {
          directory = Directory("${directory.path}/$folderName");
        }
      }

      // Create folder if it doesn't exist
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      String filePath = "${directory.path}/$fileName";
      File file = File(filePath);

      // Download file
      var response = await http.get(Uri.parse(mediaUrl));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        EasyLoading.dismiss();

        Get.snackbar(
          'Success',
          'File downloaded to ${directory.path}',
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(10),
          duration: const Duration(seconds: 4),
          backgroundColor: Colors.green,
          colorText: Colors.white,
          mainButton: TextButton(
            onPressed: () async {
              if (Platform.isAndroid) {
                // Android: Open file directly
                await OpenFilex.open(filePath);
              } else {
                // iOS: Share file to open in Files app or other apps
                await Share.shareXFiles([XFile(filePath)], text: "Open File");
              }
            },
            child: const Text(
              'Open',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
      } else {
        EasyLoading.dismiss();
        Get.snackbar(
          'Error',
          'Failed to download file',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      EasyLoading.dismiss();
      Get.snackbar(
        'Error',
        'Download failed: $e',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void donwloadFile() async {
    EasyLoading.show();
    setState(() {
      isLoading = true; // Show progress indicator
    });
    try {
      //  Directory directory = await getExternalStorageDirectory() ?? (await getApplicationDocumentsDirectory());
      //  print(directory);
      //   String fileNamess = filedirectory.basename(widget.mediaUrl);
      //   String filePath = "${directory.path}/getgabs/$fileNamess";

      //   // Create the directory if it doesn't exist
      //   Directory downloadDir = Directory("${directory.path}/getgabs");
      //   if (!await downloadDir.exists()) {
      //     print('fdksdfksdfkjdslf');
      //     await downloadDir.create(recursive: true);
      //   }

      var fileName = filedirectory.basename(widget.mediaUrl);
      var filePath = "/storage/emulated/0/Download/$fileName";
      var file = File(filePath);

      var response = await http.get(Uri.parse(widget.mediaUrl));
      debugPrint(response.body);
      if (response.statusCode == 200) {
        EasyLoading.dismiss();

        await file.writeAsBytes(response.bodyBytes);
      debugPrint("File downloaded to $filePath");
        Get.snackbar(
          'Success',
          'File downloaded to GetGabs folder.',
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.only(top: 10, left: 10, right: 10),
          duration: const Duration(seconds: 3),
          barBlur: 30,
          colorText: Colors.white,
          backgroundColor: AppTheme.appThemeColor,
          messageText: const Text(
            'Success',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          titleText: const Text(
            'File downloaded to GetGabs folder.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          mainButton: TextButton(
            onPressed: () {
              // Open the downloaded file
              OpenFilex.open(filePath);
              // OpenFile.open(filePath);
            },
            child: const Text(
              'Open',
              style: TextStyle(color: Colors.white),
            ),
          ),
        );
      } else {
        debugPrint("Failed to download file");
                // EasyLoading.dismiss();
      }
    } catch (e) {
      debugPrint("Error downloading file: $e");
              // EasyLoading.dismiss();
    } finally {
      setState(() {
        isLoading = false; // Hide progress indicator
      });
      EasyLoading.dismiss();
    }

    // var time = DateTime.now().millisecondsSinceEpoch;
    // var time = filedirectory.basename(widget.mediaUrl);
    // print(time);
    // filedirectory.basename(widget.mediaUrl);
    // var path = "/storage/emulated/0/Download/$time";
    // var file = File(path);
    // var res = await get(Uri.parse(widget.mediaUrl));
    // file.writeAsBytes(res.bodyBytes);
  }

  Future<void> _downloadFiles() async {
    try {
      var time = filedirectory.basename(widget.mediaUrl);

      String newPath = "/storage/emulated/0/Download/$time";
      await Dio().download(widget.mediaUrl, newPath,
          onReceiveProgress: (received, total) {
        if (total != -1) {
          double progress = (received / total * 100);
          debugPrint("Downloading: ${progress.toStringAsFixed(0)}%");
        }
      });
      Get.snackbar(
        'Success',
        'File downloaded to GetGabs folder.',
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.only(top: 10, left: 10, right: 10),
        duration: const Duration(seconds: 3),
        barBlur: 30,
        colorText: Colors.white,
        backgroundColor: AppTheme.appThemeColor,
        messageText: const Text(
          'Success',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white,
          ),
        ),
        titleText: const Text(
          'File downloaded to GetGabs folder.',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        mainButton: TextButton(
          onPressed: () {
            // Open the downloaded file
            OpenFilex.open(newPath);
            // OpenFile.open(newPath);
          },
          child: const Text(
            'Open',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    } catch (e) {
      Get.snackbar('Error', 'Failed to download the file: $e');
      debugPrint(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isVideo ? 'Video Preview' : 'Image Preview'),
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              // Handle download action if needed
              // donwloadFile();
              downloadFileCrossPlatform(
                widget.mediaUrl,
                folderName: "GetGabs", // optional folder name
              );
            },
          ),
        ],
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
                      : Image.network(
                          widget.mediaUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (BuildContext context, Widget child,
                              ImageChunkEvent? loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        (loadingProgress.expectedTotalBytes ??
                                            1)
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (BuildContext context, Object error,
                              StackTrace? stackTrace) {
                            return const Center(
                                child: Text('Error loading image',
                                    style: TextStyle(color: Colors.white)));
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
                const SizedBox(
                    height: 10), // Spacer between the progress bar and caption
              ],
            ),
          if (widget.caption != null && widget.caption!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                widget.caption!,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
      floatingActionButton: widget.isVideo
          ? FloatingActionButton(
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
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
