// import 'dart:io';
// import 'package:getgabs/ui/pages/dashboard/chats/templates_folder/header_selection_controller.dart';
// import 'package:path/path.dart' as path; // Import the 'path' package

// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:getgabs/data/get_storage/get_storage.dart';
// import 'package:getgabs/ui/themes/themes.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:url_launcher/url_launcher.dart';

// import '../../../../../../domain/controllers/dashboard/messages_page/messages_page_controller.dart';


// Widget _buildHeader(Map<String, dynamic> component) {
//   String format = component['format'] ?? 'TEXT';
//   String headerText = component['text'] ?? 'Header'; // Get the header text
//   var mc = Get.find<MessagesPageController>();
//   if (mc.isHeaderTemplateChange) {
//     print('99999999999999');
//     mc.clearSelection();
//     mc.validateImageSelctionError.value = false;
//     mc.isHeaderType.value = '';
//   }
//   mc.isHeaderTemplateChange = false;

//   switch (format) {
//     case 'TEXT':
//       return _buildHeaderText(component);
//     case 'IMAGE':
//       return _buildImageHeader(headerText);
//     case 'VIDEO':
//       return _buildVideoHeader(headerText);
//     case 'DOCUMENT':
//       return _buildDocumentHeader(headerText);
//     default:
//       return _buildUnknownHeader(headerText);
//   }
// }

// Widget _buildHeaderText(Map<String, dynamic> component) {
//   String headerText = component['text'] ?? '';

//   return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 16.0),
//       child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//         Text(
//           "Header Text",
//           style: TextStyle(
//             fontWeight: FontWeight.bold,
//             fontSize: 18,
//             color: Colors.black54,
//           ),
//         ),
//         Container(
//           width: double.infinity,
//           decoration: BoxDecoration(
//             border: Border.all(color: Colors.grey), // Border color
//             borderRadius: BorderRadius.circular(8), // Rounded corners
//           ),
//           padding: EdgeInsets.symmetric(
//               vertical: 4, horizontal: 14), // Padding inside the border
//           child: Text(
//             headerText,
//             style: TextStyle(
//               fontSize: 22,
//               fontWeight: FontWeight.bold,
//               color: Colors.black, // Change color as needed
//             ),
//             textAlign: TextAlign.center, // Center the header text
//           ),
//         ),
//       ]));
// }

// // Function to build an image header
// Widget _buildImageHeader(String headerText) {
//   var mc = Get.find<MessagesPageController>();
//   mc.isHeaderType.value = 'image';
//   mc.isVaribleTemplete.value = true;

//   return Column(
//     crossAxisAlignment: CrossAxisAlignment.start,
//     children: [
//       Text(
//         headerText,
//         style: TextStyle(
//           fontWeight: FontWeight.bold,
//           fontSize: 18,
//           color: Colors.black54,
//         ),
//       ),
//       SizedBox(height: 3),

//       _buildFileSelectionButton(
//           'Select Image', Icons.image, 'image'), // Use icon
//       Obx(() {
//         // Display error message below the image button if no file is selected
//         if (!mc.isFileSelected()) {
//           mc.validateImageSelctionError.value = true;

//           return Text(
//             'Image not selected',
//             style: TextStyle(color: Colors.red),
//           );
//         } else {
//           mc.validateImageSelctionError.value = false;

//           return Container(
//             width: double.infinity, // Specify the desired width
//             height: 170, // Specify the desired height
//             child: ClipRect(
//               // Optional: Clip to keep the aspect ratio
//               child: Image.file(
//                 File(mc.selectedFilePath.value),
//                 fit: BoxFit.cover, // Options include cover, contain, fill, etc.
//               ),
//             ),
//           );
//           return Image.file(File(mc.selectedFilePath
//               .value)); // No error message if a file is selected
//         }
//       }),
//     ],
//   );
// }

// // Function to build a video header
// Widget _buildVideoHeader(String headerText) {
//   var mc = Get.find<MessagesPageController>();

//   mc.isHeaderType.value = 'video';
//   mc.isVaribleTemplete.value = true;

//   return Column(
//     crossAxisAlignment: CrossAxisAlignment.start,
//     children: [
//       Text(
//         headerText,
//         style: TextStyle(
//           fontWeight: FontWeight.bold,
//           fontSize: 18,
//           color: Colors.black54,
//         ),
//       ),
//       SizedBox(height: 8),
//       _buildFileSelectionButton(
//           'Select Video', Icons.videocam, 'video'), // Use icon
//       Obx(() {
//         // Display error message below the image button if no file is selected
//         if (!mc.isFileSelected()) {
//           mc.validateImageSelctionError.value = true;

//           return Text(
//             'Video not selected',
//             style: TextStyle(color: Colors.red),
//           );
//         } else {
//           mc.validateImageSelctionError.value = false;

//           return Container(
//             width: double.infinity, // Specify the desired width
//             // height: 170, // Specify the desired height
//             child: ClipRect(
//               // Optional: Clip to keep the aspect ratio
//               child: Text(
//                 'video: ${path.basename(mc.selectedFilePath.value)}',
//                 style:
//                     TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
//               ),
//             ),
//           );
//           return Image.file(File(mc.selectedFilePath
//               .value)); // No error message if a file is selected
//         }
//       }),
//     ],
//   );
// }

// // Function to build a document header
// Widget _buildDocumentHeader(String headerText) {
//   var mc = Get.find<MessagesPageController>();

//   mc.isHeaderType.value = 'doc';
//   mc.isVaribleTemplete.value = true;

//   return Column(
//     crossAxisAlignment: CrossAxisAlignment.start,
//     children: [
//       Text(
//         headerText,
//         style: TextStyle(
//           fontWeight: FontWeight.bold,
//           fontSize: 18,
//           color: Colors.black54,
//         ),
//       ),
//       SizedBox(height: 8),
//       _buildFileSelectionButton(
//           'Select Document', Icons.description, 'document'), // Use icon
//       Obx(() {
//         // Display error message below the image button if no file is selected
//         if (!mc.isFileSelected()) {
//           mc.validateImageSelctionError.value = true;

//           return Text(
//             'Doc not selected',
//             style: TextStyle(color: Colors.red),
//           );
//         } else {
//           mc.validateImageSelctionError.value = false;

//           return Container(
//             width: double.infinity, // Specify the desired width
//             // height: 170, // Specify the desired height
//             child: ClipRect(
//               // Optional: Clip to keep the aspect ratio
//               child: Text(
//                 'Doc: ${path.basename(mc.selectedFilePath.value)}',
//                 style:
//                     TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
//               ),
//             ),
//           );
//           return Image.file(File(mc.selectedFilePath
//               .value)); // No error message if a file is selected
//         }
//       }),
//     ],
//   );
// }

// // Function to build the file selection button
// Widget _buildFileSelectionButton(String text, IconData icon, String fileType) {
//   var mc = Get.find<MessagesPageController>();
//   return SizedBox(
//     width: double.infinity, // Make the button take full width
//     child: TextButton.icon(
//       onPressed: () => mc.selectFile(fileType),
//       icon: Icon(icon,
//           color: Colors.white), // Change icon color to white for contrast
//       label: Text(
//         text,
//         style: TextStyle(
//             color: Colors.white), // Change text color to white for contrast
//       ),
//       style: TextButton.styleFrom(
//         padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//         backgroundColor: Colors.green, // Change background color to green
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(8), // Rounded corners
//         ),
//       ),
//     ),
//   );
// }

// // Function to handle unknown header types
// Widget _buildUnknownHeader(String headerText) {
//   return Text(
//     'Unknown Header Type: $headerText',
//     style: TextStyle(color: Colors.red),
//   );
// }

// Widget _buildBodyText(Map<String, dynamic> component) {
//   String bodyText = component['text'] ?? '';
//   final mc = Get.find<MessagesPageController>();

//   // Create a RegExp to find variable placeholders like {{1}}, {{2}}, etc.
//   RegExp regExp = RegExp(r'\{\{(\d+)\}\}');
//   List<InlineSpan> spans = [];
//   int lastMatchEnd = 0;
//   List<String> variablePlaceholders = []; // To store variable identifiers

//   // Find all matches and split the text accordingly
//   for (final match in regExp.allMatches(bodyText)) {
//     mc.isVaribleTemplete.value = true;
//     // Add text before the match
//     if (match.start > lastMatchEnd) {
//       spans.add(TextSpan(text: bodyText.substring(lastMatchEnd, match.start)));
//     }
//     // Add the placeholder text
//     String placeholder = match.group(0) ?? '';
//     spans.add(TextSpan(
//       text: placeholder,
//       style: TextStyle(
//           fontWeight: FontWeight.bold,
//           color: Colors.blue), // Style for the placeholder
//     ));
//     variablePlaceholders.add(placeholder); // Store the placeholder
//     lastMatchEnd = match.end;
//   }

//   // Add the remaining text after the last match
//   if (lastMatchEnd < bodyText.length) {
//     spans.add(TextSpan(text: bodyText.substring(lastMatchEnd)));
//   }
//   print('hellow there');
//   // Initialize dynamic text controllers based on variable placeholders
//   if (mc.isTemplateSelectChange) {
//     mc.initializeControllers(variablePlaceholders);
//   }
//   mc.isTemplateSelectChange = false;
//   return Column(
//     crossAxisAlignment: CrossAxisAlignment.start,
//     children: [
//       Text(
//         "Body Text:",
//         style: TextStyle(
//           fontWeight: FontWeight.bold,
//           fontSize: 18,
//           color: Colors.black54,
//         ),
//       ),
//       SizedBox(height: 4),
//       Container(
//         decoration: BoxDecoration(
//           border: Border.all(color: Colors.grey), // Border color
//           borderRadius: BorderRadius.circular(8), // Rounded corners
//         ),
//         padding: EdgeInsets.all(16), // Padding inside the border
//         child: RichText(
//           text: TextSpan(
//             style: TextStyle(color: Colors.black), // Base text style
//             children: spans,
//           ),
//         ),
//       ),
//       SizedBox(height: 8),
//       // Use a ListView.builder for dynamic input fields
//       ListView.builder(
//         shrinkWrap: true,
//         physics: NeverScrollableScrollPhysics(), // Disable scrolling
//         itemCount: variablePlaceholders.length,
//         itemBuilder: (context, index) {
//           return Padding(
//             padding: const EdgeInsets.only(top: 8.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text('Body Variable ${index + 1}:',
//                     style: TextStyle(fontWeight: FontWeight.bold)),
//                 // Wrap each TextField in Obx to make it reactive
//                 Obx(() {
//                   return TextField(
//                     controller: mc.dynamicTextControllers[index],
//                     decoration: InputDecoration(
//                       border: OutlineInputBorder(),
//                       errorText: mc.validationErrors[index]
//                           ? 'This field cannot be empty'
//                           : null,
//                     ),
//                   );
//                 }),
//               ],
//             ),
//           );
//         },
//       ),
//       SizedBox(height: 8), // Space
//     ],
//   );
// }

// Widget _buildInputField() {
//   return TextField(
//     decoration: InputDecoration(
//       border: OutlineInputBorder(),
//       hintText: 'Enter value',
//     ),
//   );
// }

// Widget _buildFooterText(Map<String, dynamic> component) {
//   String footerText = component['text'] ?? '';

//   return Column(
//     crossAxisAlignment: CrossAxisAlignment.start,
//     children: [
//       Text(
//         "Footer Text:",
//         style: TextStyle(
//           fontWeight: FontWeight.bold,
//           fontSize: 18,
//           color: Colors.black54,
//         ),
//       ),
//       SizedBox(height: 4),

//       Container(
//         decoration: BoxDecoration(
//           border: Border.all(color: Colors.grey), // Border color
//           borderRadius: BorderRadius.circular(8), // Rounded corners
//         ),
//         padding: EdgeInsets.symmetric(
//             vertical: 4, horizontal: 14), // Padding inside the border
//         child: TextField(
//           controller:
//               TextEditingController(text: footerText), // Set footer text
//           readOnly: true, // Make it non-editable
//           decoration: InputDecoration(
//             border: InputBorder.none, // Remove the border for the text field
//           ),
//         ),
//       ),
//       SizedBox(height: 16), // Space between footer and buttons
//     ],
//   );
// }

// Widget _buildButtons(List<dynamic> buttons) {
//   print('hoo there');
//   final mc = Get.find<MessagesPageController>();
//   int copyCount = 0;
//   // return Text('data');

//   return Column(
//     crossAxisAlignment: CrossAxisAlignment.start,
//     children: buttons.asMap().entries.map((entry) {
//       int index = entry.key; // Get the index
//       var button = entry.value; // Get the button object

//       //  buttons.map((button) {
//       String buttonType = (button['type'] ?? 'default').toLowerCase();
//       String buttonText = button['text'] ?? 'Button';
//       String urlTemplate = button['url'] ?? '';
//       List<String> variablePlaceholders = [];

//       if (buttonType == 'url') {
//         variablePlaceholders = _extractPlaceholders(urlTemplate);
//         if (variablePlaceholders.isNotEmpty) {
//           mc.isVaribleTemplete.value = true;
//         }
//         if (mc.isButtonTemplateChange) {
//           print('99999999999999');
//           mc.initializeUrlControllers(variablePlaceholders);
//         }
//         mc.isButtonTemplateChange = false;
//       }

//       if (buttonType == 'copy_code') {
//         if (mc.isButtonCCTemplateChange) {
//           print(buttonType == 'copy_code');

//           mc.initializeCopyCodeControllers(copyCount + 1);

//           print('state hghj');
//         }
//         mc.isButtonCCTemplateChange = false;
//       }

//       // if (mc.isButtonTemplateChange) {
//       //   print('is ima here');
//       //   mc.clearUrlPreviousData();
//       // }

//       // if (mc.isButtonCCTemplateChange) {
//       //   mc.clearCopyCodePreviousData();
//       // }

//       return Padding(
//         padding: const EdgeInsets.all(8.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             _buildButtonLabel(buttonType),
//             SizedBox(height: 4),
//             if (buttonType == 'copy_code')
//               _buildCopyCodeButton(button, copyCount + 1),
//             if (buttonType == 'url')
//               _buildUrlButton(urlTemplate, variablePlaceholders),
//             if (buttonType != 'copy_code' && buttonType != 'url')
//               _buildDefaultButton(buttonType, buttonText),
//           ],
//         ),
//       );
//     }).toList(),
//   );
// }

// // Function to extract URL placeholders
// List<String> _extractPlaceholders(String urlTemplate) {
//   RegExp regExp = RegExp(r'\{\{(\d+)\}\}');
//   return regExp
//       .allMatches(urlTemplate)
//       .map((match) => match.group(0) ?? '')
//       .toList();
// }

// // Function to build the label for each button
// Widget _buildButtonLabel(String buttonType) {
//   return Text(
//     '$buttonType BUTTON'.toUpperCase(),
//     style: TextStyle(
//       fontWeight: FontWeight.bold,
//       fontSize: 16,
//       color: Colors.black54,
//     ),
//   );
// }

// // Function to build the COPY_CODE button with input
// Widget _buildCopyCodeButton(Map<String, dynamic> button, int index) {
//   index = index - 1;
//   print('state  changed');
//   String exampleCode = button['example']?.first ?? '';
//   TextEditingController _codeController = TextEditingController();
//   final mc = Get.find<MessagesPageController>();
//   // if (mc.isButtonTemplateChange) {
//   //  mc. clearCopyCodePreviousData();
//   // }
//   // mc.initializeCopyCodeControllers(index);
//   return Column(
//     crossAxisAlignment: CrossAxisAlignment.start,
//     children: [
//       Container(
//         width: 300,
//         child: Obx(() {
//           return TextField(
//             controller: mc.dynamicCopyCodeTextControllers[index],
//             decoration: InputDecoration(
//               border: OutlineInputBorder(),
//               hintText: exampleCode,
//               errorText: mc.validationCopyCodeButtonErrors[index]
//                   ? 'This field cannot be empty'
//                   : null,
//             ),
//           );
//         }),
//       ),
//       SizedBox(height: 8),
//     ],
//   );
// }

// Widget _buildUrlButton(String urlTemplate, List<String> variablePlaceholders) {
//   final mc = Get.find<MessagesPageController>();

//   return Column(
//     crossAxisAlignment: CrossAxisAlignment.start,
//     children: [
//       // Display the full URL
//       Container(
//         width: 300,
//         child: TextField(
//           controller: TextEditingController(text: urlTemplate),
//           readOnly: true,
//           decoration: InputDecoration(
//             border: OutlineInputBorder(),
//             labelText: 'Full URL',
//           ),
//         ),
//       ),
//       SizedBox(height: 8),

//       // Display the dynamic variable input fields
//       ListView.builder(
//         shrinkWrap: true,
//         physics: NeverScrollableScrollPhysics(), // Disable scrolling
//         itemCount: variablePlaceholders.length,
//         itemBuilder: (context, index) {
//           String placeholder = variablePlaceholders[index];
//           return Padding(
//             padding: const EdgeInsets.only(top: 8.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text('Variable ${index + 1}:',
//                     style: TextStyle(fontWeight: FontWeight.bold)),
//                 Obx(() {
//                   return TextField(
//                     controller: mc.dynamicButtonTextControllers[index],
//                     decoration: InputDecoration(
//                       border: OutlineInputBorder(),
//                       hintText: 'Enter value for $placeholder',
//                       errorText: mc.validationButtonErrors[index]
//                           ? 'This field cannot be empty'
//                           : null,
//                     ),
//                   );
//                 }),
//               ],
//             ),
//           );
//         },
//       ),
//     ],
//   );
// }

// // Function to build the URL button and its variable inputs
// Widget _buildUrlButtonold(
//     String urlTemplate, List<String> variablePlaceholders) {
//   return Column(
//     crossAxisAlignment: CrossAxisAlignment.start,
//     children: [
//       Container(
//         width: 300,
//         child: TextField(
//           controller: TextEditingController(text: urlTemplate),
//           readOnly: true,
//           decoration: InputDecoration(
//             border: OutlineInputBorder(),
//             labelText: 'Full URL',
//           ),
//         ),
//       ),
//       ...variablePlaceholders.asMap().entries.map((entry) {
//         int index = entry.key;
//         String placeholder = entry.value;

//         return Padding(
//           padding: const EdgeInsets.only(top: 8.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text('Variable ${index + 1}:',
//                   style: TextStyle(fontWeight: FontWeight.bold)),
//               Container(
//                 width: 300,
//                 child: TextField(
//                   decoration: InputDecoration(
//                     border: OutlineInputBorder(),
//                     hintText: 'Enter value for $placeholder',
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         );
//       }).toList(),
//     ],
//   );
// }

// // Function to build a default action button
// Widget _buildDefaultButton(String buttonType, String buttonText) {
//   return ElevatedButton(
//     onPressed: () {
//       // Handle button actions based on type
//       if (buttonType == 'action') {
//         // Perform some action
//       } else {
//         print('Button pressed: $buttonText');
//       }
//     },
//     child: Text(buttonText),
//     style: ElevatedButton.styleFrom(
//       padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(8),
//       ),
//     ),
//   );
// }

// Widget _buildCarousel(List<dynamic> cards) {
//   PageController _pageController = PageController();
//   var _currentPage = 0.obs; // Track the current page index

//   return Column(
//     children: [
//       SizedBox(
//         height: 500, // Set height for carousel
//         child: PageView.builder(
//           controller: _pageController,
//           itemCount: cards.length,
//           onPageChanged: (index) {
//             // Update current page index when the page changes
//             _currentPage.value = index;
//           },
//           itemBuilder: (context, index) {
//             var card = cards[index];
//             List<Widget> cardWidgets = [];

//             // Loop through components within each card
//             for (var component in card['components']) {
//               // buildTemplateUi(component);
//               switch (component['type']) {
//                 case 'HEADER':
//                   // cardWidgets.add(_buildHeader(component));
//                   cardWidgets.add(HeaderWidget(component: component));

//                   break;
//                 case 'BODY':
//                   cardWidgets.add(_buildBodyText(component));
//                   break;
//                 case 'BUTTONS':
//                   cardWidgets.add(_buildButtons(component['buttons']));
//                   break;
//                 default:
//                   // Handle other component types if necessary
//                   break;
//               }
//             }
//             return SingleChildScrollView(
//               child: Card(
//                 margin: EdgeInsets.all(8),
//                 child: Padding(
//                   padding: const EdgeInsets.all(8.0),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: cardWidgets,
//                   ),
//                 ),
//               ),
//             );
//           },
//         ),
//       ),
//       SizedBox(height: 8), // Space between carousel and indicator
//       Obx(() => Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: List.generate(cards.length, (index) {
//               return Container(
//                 margin: const EdgeInsets.symmetric(horizontal: 4),
//                 width: 8,
//                 height: 8,
//                 decoration: BoxDecoration(
//                   shape: BoxShape.circle,
//                   color: _currentPage.value == index
//                       ? Colors.blue
//                       : Colors.grey, // Change color based on active page
//                 ),
//               );
//             }),
//           )),
//       SizedBox(height: 8), // Space between indicator and hint
//       Text(
//         "Swipe to see more",
//         style: TextStyle(
//           fontSize: 16,
//           color: Colors.black54,
//         ),
//       ),
//     ],
//   );
// }
