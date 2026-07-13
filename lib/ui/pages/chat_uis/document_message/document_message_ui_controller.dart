import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;

class DocumentController extends GetxController {
  final String documentUrl; // URL of the document to download
  var isDownloading = false.obs;
  var downloadProgress = 0.obs;
  var isLocal = false;

  DocumentController(this.documentUrl, {required this.isLocal});

  // Download the document
  Future<void> downloadDocument() async {
    try {
      // final url =documentUrl;
      // final filename = url.split('/').last;
      // final Directory directory = await getApplicationDocumentsDirectory();
      // final filePath = '${directory.path}/$filename';

      //   final response = await Dio().download(url, filePath);
      // if (response.statusCode == 200) {

      // }

      isDownloading.value = true;
      final directory = await getApplicationDocumentsDirectory();

      print(documentUrl);
      String filePath = isLocal
          ? documentUrl
          : "${directory.path}/${path.basename(documentUrl)}";

      if (isLocal) {
        openDocument(filePath);
      } else {
        Dio dio = Dio();
        final response = await dio.download(
          documentUrl,
          filePath,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              downloadProgress.value = (received / total * 100).toInt();
            }
          },
        );
        if (response.statusCode == 200) {
          Get.snackbar('Success', 'Document downloaded successfully');
          openDocument(filePath);
        }
        isDownloading.value = false;
      }
    } catch (e) {
      isDownloading.value = false;
      Get.snackbar('Error', 'Failed to download the document: $e');
    }
  }
// Future<void> openDocument(String filePath) async {
//   // List of allowed file extensions
//   final allowedExtensions = [
//     'pdf',
//     'xlsx',
//     'xls',
//     'txt',
//     'xlsm',
//     'xlsb',
//     'xltx',
//     'doc',
//     'docx',
//     'csv',
//     'avi',
//     'ppt',
//     'pptx',
//     'avchd',
//   ];

//   // Get the file extension
//   final fileExtension = filePath.split('.').last.toLowerCase();

//   // Check if the file extension is allowed
//   if (allowedExtensions.contains(fileExtension)) {
//     if (await File(filePath).exists()) {
//       OpenFile.open(filePath);
//     } else {
//       Get.snackbar('Error', 'File not found');
//     }
//   } else {
//     Get.snackbar('Error', 'File type not supported');
//   }
// }

  Future<void> openDocument(String filePath) async {
    if (await File(filePath).exists()) {
      OpenFilex.open(filePath);
      // OpenFile.open(filePath);
    } else {
      Get.snackbar('Error', 'File not found');
    }
  }
}
