import 'dart:io';
import 'package:getgabs/ui/pages/dashboard/chats/templates_folder/carousal/header_selection_controller.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

class HeaderWidget extends StatelessWidget {
  final Map<String, dynamic> component;
  final int index;
  final int cardLength;

  const HeaderWidget(
      {super.key, required this.component, required this.index, required this.cardLength});

  @override
  Widget build(BuildContext context) {
    return _buildHeader(component, index);
  }

  Widget _buildHeader(
    Map<String, dynamic> component,
    int i,
  ) {
    String format = component['format'] ?? 'TEXT';
    String headerText = component['text'] ?? 'Header';
    // var mc  = Get.find<MessagesPageController>();
    // print('crousel state rebuild !!!!!!!!!!!!!!');
    // if(i<cardLength){
    //         hc.intilizeSelections(i);

    // }

    // mc.clearSelection(i); // Clear previous selections

    switch (format) {
      case 'TEXT':
        return _buildHeaderText(component);
      case 'IMAGE':
        return _buildImageHeader(headerText, i);
      case 'VIDEO':
        return _buildVideoHeader(headerText, i);
      case 'DOCUMENT':
        return _buildDocumentHeader(headerText, i);
      default:
        return _buildUnknownHeader(headerText);
    }
  }

  Widget _buildHeaderText(Map<String, dynamic> component) {
    String headerText = component['text'] ?? '';

    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            "Header Text",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.black54,
            ),
          ),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey), // Border color
              borderRadius: BorderRadius.circular(8), // Rounded corners
            ),
            padding: const EdgeInsets.symmetric(
                vertical: 4, horizontal: 14), // Padding inside the border
            child: Text(
              headerText,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black, // Change color as needed
              ),
              textAlign: TextAlign.center, // Center the header text
            ),
          ),
        ]));
  }

// Function to build an image header
  Widget _buildImageHeader(String headerText, int i) {
    var mc = Get.find<HeaderSelectionController>();
    mc.isHeaderType.value = 'image';
    mc.isVaribleTemplete.value = true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headerText,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 3),

        _buildFileSelectionButton(
            'Select Image', Icons.image, 'image', i), // Use icon

        // !mc.isFileSelected(i)
        //     ? Text(
        //         'Image not selected',
        //         style: TextStyle(color: Colors.red),
        //       )
        //     :
        //     Obx(()=>Container(
        //         width: double.infinity, // Specify the desired width
        //         height: 170, // Specify the desired height
        //         child: ClipRect(
        //           // Optional: Clip to keep the aspect ratio
        //           child: Image.file(
        //             File(mc.selectedFilePath[i]),
        //             fit: BoxFit
        //                 .cover, // Options include cover, contain, fill, etc.
        //           ),
        //         ),
        //       ))

        //     ,
        Obx(() {
          // Display error message below the image button if no file is selected
          if (!mc.isFileSelected(i)) {
            // mc.validateImageSelctionError.value = true;

            return const Text(
              'Image not selected',
              style: TextStyle(color: Colors.red),
            );
          } else {
            // mc.validateImageSelctionError.value = false;

            return SizedBox(
              width: double.infinity, // Specify the desired width
              height: 170, // Specify the desired height
              child: ClipRect(
                // Optional: Clip to keep the aspect ratio
                child: Image.file(
                  File(mc.selectedFilePath[i]),
                  fit: BoxFit
                      .cover, // Options include cover, contain, fill, etc.
                ),
              ),
            );
          }
        }),
      ],
    );
  }

// Function to build a video header
  Widget _buildVideoHeader(String headerText, int i) {
    var mc = Get.find<HeaderSelectionController>();

    mc.isHeaderType.value = 'video';
    mc.isVaribleTemplete.value = true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headerText,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        _buildFileSelectionButton(
            'Select Video', Icons.videocam, 'video', i), // Use icon
        // Obx(() {
        //   // Display error message below the image button if no file is selected
        //   if (!mc.isFileSelected(i)) {
        //     mc.validateImageSelctionError.value = true;

        //     return Text(
        //       'Video not selected',
        //       style: TextStyle(color: Colors.red),
        //     );
        //   } else {
        //     mc.validateImageSelctionError.value = false;

        //     return Container(
        //       width: double.infinity, // Specify the desired width
        //       // height: 170, // Specify the desired height
        //       child: ClipRect(
        //         // Optional: Clip to keep the aspect ratio
        //         child: Text(
        //           'video: ${path.basename(mc.selectedFilePath[i])}',
        //           style:
        //               TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
        //         ),
        //       ),
        //     );
        //   }
        // }),
      ],
    );
  }

// Function to build a document header
  Widget _buildDocumentHeader(String headerText, int i) {
    var mc = Get.find<HeaderSelectionController>();

    mc.isHeaderType.value = 'doc';
    mc.isVaribleTemplete.value = true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headerText,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        _buildFileSelectionButton(
            'Select Document', Icons.description, 'document', i), // Use icon
        // Obx(() {
        //   // Display error message below the image button if no file is selected
        //   if (!mc.isFileSelected(i)) {
        //     mc.validateImageSelctionError.value = true;

        //     return Text(
        //       'Doc not selected',
        //       style: TextStyle(color: Colors.red),
        //     );
        //   } else {
        //     mc.validateImageSelctionError.value = false;

        //     return Container(
        //       width: double.infinity, // Specify the desired width
        //       // height: 170, // Specify the desired height
        //       child: ClipRect(
        //         // Optional: Clip to keep the aspect ratio
        //         child: Text(
        //           'Doc: ${path.basename(mc.selectedFilePath[i])}',
        //           style:
        //               TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
        //         ),
        //       ),
        //     );
        //   }
        // }),
      ],
    );
  }

// Function to build the file selection button
  Widget _buildFileSelectionButton(
      String text, IconData icon, String fileType, int i) {
    var mc = Get.find<HeaderSelectionController>();
    return SizedBox(
      width: double.infinity, // Make the button take full width
      child: TextButton.icon(
        onPressed: () => mc.selectFile(fileType, i),
        icon: Icon(icon,
            color: Colors.white), // Change icon color to white for contrast
        label: Text(
          text,
          style: const TextStyle(
              color: Colors.white), // Change text color to white for contrast
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          backgroundColor: Colors.green, // Change background color to green
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8), // Rounded corners
          ),
        ),
      ),
    );
  }

// Function to handle unknown header types
  Widget _buildUnknownHeader(String headerText) {
    return Text(
      'Unknown Header Type: $headerText',
      style: const TextStyle(color: Colors.red),
    );
  }
}
