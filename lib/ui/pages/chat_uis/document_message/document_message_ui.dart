import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getgabs/ui/pages/chat_uis/base_message_ui.dart';
import 'package:getgabs/ui/pages/chat_uis/document_message/document_message_ui_controller.dart';
import 'dart:io'; // Ensure you have this for File operations
import 'package:path/path.dart' as path;

class DocumentMessageUi extends StatelessWidget {
  final String documentFile;
  final bool isSentByMe;
  final DateTime createdAt;
  final Size mediaQuery;
  final double rightMargin;
  final double leftMargin;
  final bool isInTemplate; // New parameter to check if in template
  final bool isLocal;
  final String deliveryStatus;

  const DocumentMessageUi({
    super.key,
    required this.documentFile,
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
    return BaseMessageUi(
      isSentByMe: isSentByMe,
      createdAt: createdAt,
      mediaQuery: mediaQuery,
      deliveryStatus: deliveryStatus,
      child: Center(
        child: GetBuilder<DocumentController>(
          init: DocumentController(documentFile, isLocal: isLocal),
          global: false,
          builder: (controller) {
            if (deliveryStatus == 'failed') {
              // Show blurred placeholder if the document failed to download
              return _buildBlurredDocumentPlaceholder();
            } else {
              // Show the actual document widget
              return _buildDocumentWidget(controller);
            }
          },
        ),
      ),
    );
  }

  Widget _buildDocumentWidget(DocumentController controller) {
    String fileName = path.basename(documentFile);

    return Container(
      margin: EdgeInsets.only(top: mediaQuery.height * 0.01),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isSentByMe ? Colors.grey[100] : Colors.grey[300],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _getDocumentIcon(
                  documentFile), // Display icon based on document type
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  fileName,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              Obx(() {
                if (controller.isDownloading.value) {
                  return SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      value: controller.downloadProgress.value / 100,
                      strokeWidth: 2,
                    ),
                  );
                } else {
                  return IconButton(
                    icon: const Icon(Icons.download_rounded),
                    onPressed: () {
                      controller.downloadDocument();
                    },
                  );
                }
              }),
            ],
          ),
          const SizedBox(height: 5),
          // Row(
          //   children: [
          //     Text(
          //       'Size: ${_getFileSize()}',
          //       style: const TextStyle(fontSize: 14, color: Colors.black54),
          //     ),
          //   ],
          // ),
        ],
      ),
    );
  }

  Widget _getDocumentIcon(String filePath) {
    try {
              return const Icon(Icons.insert_drive_file,
            color: Colors.green, size: 32);

      String fileExtension = path.extension(filePath).toLowerCase();

      if (['.jpg', '.jpeg', '.png', '.gif'].contains(fileExtension)) {
        // If it's an image file, return an image preview
        return Image.file(
          File(filePath),
          width: 50,
          height: 50,
          fit: BoxFit.cover,
        );
      } else if (fileExtension == '.pdf') {
        // Return a PDF icon for PDF files, or use a PDF thumbnail package
        return const Icon(Icons.picture_as_pdf, color: Colors.red, size: 32);
      } else {
        // For other document types, return a generic document icon
        return const Icon(Icons.insert_drive_file,
            color: Colors.green, size: 32);
      }
    } catch (e) {
      print(e);
      return const Text('');
    } finally {}
  }

  Widget _buildBlurredDocumentPlaceholder() {
    return Container(
      width: double.infinity,
      height: 100, // You can adjust this height
      decoration: BoxDecoration(
        color: Colors.red[200],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: const Center(
        child: Text(
          'Document not available',
          style: TextStyle(color: Colors.black54),
        ),
      ),
    );
  }

  // Method to get file size
  String _getFileSize() {
    try {
      File file = File(documentFile); // Assuming documentFile is the file path
      if (file.existsSync()) {
        int bytes = file.lengthSync(); 
        return _formatBytes(bytes);
      } else {
        return '';
      }
    } catch (e) {
      return 'Error retrieving size';
    }
  }

  // Helper method to format bytes into a more readable string
  String _formatBytes(int bytes, [int decimalPlaces = 2]) {
    if (bytes <= 0) return "0 Bytes";
    const List<String> units = ["Bytes", "KB", "MB", "GB", "TB"];
    int i = (log(bytes) / log(1024)).floor();
    return "${(bytes / pow(1024, i)).toStringAsFixed(decimalPlaces)} ${units[i]}";
  }
}
