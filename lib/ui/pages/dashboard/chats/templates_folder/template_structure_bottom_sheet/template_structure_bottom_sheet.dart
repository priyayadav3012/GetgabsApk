import 'dart:io';

import 'package:get/get.dart';
// import 'package:path/path.dart' as path; // Import the 'path' package
import 'package:path/path.dart' as path; // Import the 'path' package

import 'package:flutter/material.dart';
import 'package:getgabs/ui/pages/dashboard/chats/templates_folder/template_structure_bottom_sheet/template_stucture_bottom_sheet_controller.dart';

import '../../../../../themes/themes.dart';

class TemplateStructureBottomSheet extends StatelessWidget {
  var templateController = Get.find<TemplateStuctureBottomSheetController>();
  // Get.put(TemplateStuctureBottomSheetController());

  TemplateStructureBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24.0),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: NotificationListener<ScrollNotification>(
            onNotification: (scrollNotification) {
              // Handle additional behavior if needed
              return false; // return false to allow the scroll event to propagate
            },
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    height: 40,
                  ),
                  _buildTitle('Send Campaign Individually'),
                  const SizedBox(height: 16),
                  // _buildLabel('Choose Template'),
                  Obx(() {
                    if (templateController.templateStructure.isNotEmpty) {
                      print('widget rebuild again...');
                      return buildTemplateUi(
                          templateController.templateStructure);
                    } else {
                      if (templateController.isTempStrucProgress.value) {
                        return const Center(child: CircularProgressIndicator());
                      } else {
                        return const Text('Not able to load');
                      }
                    }
                  }),

                  _buildSendButton()
                  // templateController.templateStructure.isNotEmpty? :

                  // Obx(() {
                  //   return templateController.isTempStrucProgress.value
                  //       ? Padding(
                  //           padding: const EdgeInsets.all(16.0),
                  //           child: Center(child: CircularProgressIndicator()))
                  //       : templateController.templateStructure.isNotEmpty
                  //           ? Padding(
                  //               padding: const EdgeInsets.all(16.0),
                  //               child: Text("data")
                  //               //  buildTemplateUi(
                  //               //     templateController.templateStructure),
                  //               )
                  //           : templateController.errorMessage.isNotEmpty
                  //               ? Text(templateController.errorMessage.value)
                  //               : Text('');
                  // }),
                  // Obx(() {
                  //   if (templateController.isCarousal.value) {
                  //     return Center(
                  //         child: Text(
                  //       'Coming Soon',
                  //       style: TextStyle(
                  //           color: Colors.indigo,
                  //           fontWeight: FontWeight.bold,
                  //           fontSize: 22),
                  //     ));
                  //   } else {
                  //     return _buildSendButton();
                  //   }
                  // }),
                ],
              ),
            ),
          )),
    );
  }

  Widget _buildSendButton() {
    final mc = Get.find<TemplateStuctureBottomSheetController>();
    return Center(
      child: ElevatedButton(
        onPressed: () {
          print(mc.dynamicTextControllers.length);
          print(mc.dynamicUrlButtonTextControllers.length.toString());
          if (!mc.isVaribleTemplete.value) {
            // mc.processAndSendTemplate();

            // Get.back();
            // Get.back(); // Goes back another screen
            mc.isTempStrucProgress.value = true;
          } else {
            // print('666666666666');

            mc.validateInputs();

            mc.validateUrlInputs();

            mc.validateCopyCodeInputs();

            if (mc.isHeaderType.value == 'image') {
              if (mc.isFileSelected()) {
                mc.validateImageSelctionError.value = false;
              }
            } else if (mc.isHeaderType.value == 'video') {
              if (mc.isFileSelected()) {
                mc.validateImageSelctionError.value = false;
              } else if (mc.isHeaderType.value == 'doc') {
                if (mc.isFileSelected()) {
                  mc.validateImageSelctionError.value = false;
                }
              }
            }

            if (!mc.validationErrors.contains(true) &&
                !mc.validationButtonErrors.contains(true) &&
                !mc.validationCopyCodeButtonErrors.contains(true) &&
                !mc.validateImageSelctionError.value) {
              // mc.processAndSendTemplate();
              // mc.isTempStrucProgress.value=true;
              // Get.back();
              // Get.back(); // Goes back another screen
              mc.isTempStrucProgress.value = true;
            } else {
              print('There are validation errors.');
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.appThemeColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
        ),
        child: const Text(
          "Send",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
  //---------------------------------------------------------------------------------

  Widget buildTemplateUi(RxMap<String, dynamic> templateData) {
    List<Widget> widgetList = [];
    print('yes yes yes');

    var mc = Get.find<TemplateStuctureBottomSheetController>();

    // if (mc.isButtonTemplateChange) {
    //   print('is ima here');
    //   mc.clearUrlPreviousData();
    // }

    // if (mc.isButtonCCTemplateChange) {
    //   mc.clearCopyCodePreviousData();
    // }
    // if(mc.formatTypes['CAROUSEL'] ){
    // return    Column(
    //     crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Not Available right Now!')]);

    // }

    // Loop through the components
    for (var component in templateData['components']) {
      switch (component['type']) {
        case 'HEADER':
          widgetList.add(_buildHeader(component));
          break;
        case 'BODY':
          widgetList.add(_buildBodyText(component));
          break;
        case 'FOOTER':
          widgetList.add(_buildFooterText(component));
          break;
        case 'BUTTONS':
          widgetList.add(_buildButtons(component['buttons']));
          break;
        case 'CAROUSEL':
          WidgetsBinding.instance.addPostFrameCallback((_) {
            mc.isCarousal.value = true;
          });
          // widgetList.add(Text('Not Available Right Now!'));
          //widgetList.add(_buildCarousel(component['cards']));
          break;

        default:
          widgetList.add(const Text('Not Available Right Now!'));

          // Handle other component types like media if necessary
          break;
      }
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: widgetList);
  }

  Widget _buildHeader(Map<String, dynamic> component) {
    String format = component['format'] ?? 'TEXT';
    String headerText = component['text'] ?? 'Header'; // Get the header text
    var mc = Get.find<TemplateStuctureBottomSheetController>();
    // if (mc.isHeaderTemplateChange) {
    //   print('99999999999999');
    //   mc.clearSelection();
    //   mc.validateImageSelctionError.value = false;
    //   mc.isHeaderType.value = '';
    // }
    // mc.isHeaderTemplateChange = false;

    switch (format) {
      case 'TEXT':
        return _buildHeaderText(component);
      case 'IMAGE':
        return _buildImageHeader(headerText);
      case 'VIDEO':
        return _buildVideoHeader(headerText);
      case 'DOCUMENT':
        return _buildDocumentHeader(headerText);
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
  Widget _buildImageHeader(String headerText) {
    var mc = Get.find<TemplateStuctureBottomSheetController>();
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
            'Select Image', Icons.image, 'image'), // Use icon
        Obx(() {
          // Display error message below the image button if no file is selected
          if (!mc.isFileSelected()) {
            mc.validateImageSelctionError.value = true;

            return const Text(
              'Image not selected',
              style: TextStyle(color: Colors.red),
            );
          } else {
            mc.validateImageSelctionError.value = false;

            return SizedBox(
              width: double.infinity, // Specify the desired width
              height: 170, // Specify the desired height
              child: ClipRect(
                // Optional: Clip to keep the aspect ratio
                child: Image.file(
                  File(mc.selectedFilePath.value),
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
  Widget _buildVideoHeader(String headerText) {
    var mc = Get.find<TemplateStuctureBottomSheetController>();

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
            'Select Video', Icons.videocam, 'video'), // Use icon
        Obx(() {
          // Display error message below the image button if no file is selected
          if (!mc.isFileSelected()) {
            mc.validateImageSelctionError.value = true;

            return const Text(
              'Video not selected',
              style: TextStyle(color: Colors.red),
            );
          } else {
            mc.validateImageSelctionError.value = false;

            return SizedBox(
              width: double.infinity, // Specify the desired width
              // height: 170, // Specify the desired height
              child: ClipRect(
                // Optional: Clip to keep the aspect ratio
                child: Text(
                  'video: ${path.basename(mc.selectedFilePath.value)}',
                  style: const TextStyle(
                      color: Colors.blue, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }
        }),
      ],
    );
  }

// Function to build a document header
  Widget _buildDocumentHeader(String headerText) {
    var mc = Get.find<TemplateStuctureBottomSheetController>();

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
            'Select Document', Icons.description, 'document'), // Use icon
        Obx(() {
          // Display error message below the image button if no file is selected
          if (!mc.isFileSelected()) {
            mc.validateImageSelctionError.value = true;

            return const Text(
              'Doc not selected',
              style: TextStyle(color: Colors.red),
            );
          } else {
            mc.validateImageSelctionError.value = false;

            return SizedBox(
              width: double.infinity, // Specify the desired width
              // height: 170, // Specify the desired height
              child: ClipRect(
                // Optional: Clip to keep the aspect ratio
                child: Text(
                  'Doc: ${path.basename(mc.selectedFilePath.value)}',
                  style: const TextStyle(
                      color: Colors.blue, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }
        }),
      ],
    );
  }

// Function to build the file selection button
  Widget _buildFileSelectionButton(
      String text, IconData icon, String fileType) {
    var mc = Get.find<TemplateStuctureBottomSheetController>();
    return SizedBox(
      width: double.infinity, // Make the button take full width
      child: TextButton.icon(
        onPressed: () => mc.selectFile(fileType),
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

  Widget _buildBodyText(Map<String, dynamic> component) {
    String bodyText = component['text'] ?? '';
    final mc = Get.find<TemplateStuctureBottomSheetController>();

    // Create a RegExp to find variable placeholders like {{1}}, {{2}}, etc.
    RegExp regExp = RegExp(r'\{\{(\d+)\}\}');
    List<InlineSpan> spans = [];
    int lastMatchEnd = 0;
    List<String> variablePlaceholders = []; // To store variable identifiers

    // Find all matches and split the text accordingly
    for (final match in regExp.allMatches(bodyText)) {
      mc.isVaribleTemplete.value = true;
      // Add text before the match
      if (match.start > lastMatchEnd) {
        spans
            .add(TextSpan(text: bodyText.substring(lastMatchEnd, match.start)));
      }
      // Add the placeholder text
      String placeholder = match.group(0) ?? '';
      spans.add(
        TextSpan(
          text: placeholder,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue), // Style for the placeholder
        ),
      );
      variablePlaceholders.add(placeholder); // Store the placeholder
      lastMatchEnd = match.end;
    }

    // Add the remaining text after the last match
    if (lastMatchEnd < bodyText.length) {
      spans.add(TextSpan(text: bodyText.substring(lastMatchEnd)));
    }
    // Initialize dynamic text controllers based on variable placeholders
    // if (mc.isTemplateSelectChange) {
    //   print(variablePlaceholders);
    if (mc.dynamicUrlButtonTextControllers.isEmpty) {
      mc.initializeControllers(variablePlaceholders);
    }
    // }
    mc.isTemplateSelectChange = false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Body Text:",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey), // Border color
            borderRadius: BorderRadius.circular(8), // Rounded corners
          ),
          padding: const EdgeInsets.all(16), // Padding inside the border
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black), // Base text style
              children: spans,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Use a ListView.builder for dynamic input fields
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(), // Disable scrolling
          itemCount: variablePlaceholders.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Body Variable ${index + 1}:',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  // Wrap each TextField in Obx to make it reactive

                  Obx(() {
                    print('hellow there1');

                    return TextField(
                      controller: mc.dynamicTextControllers[index],
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        errorText: mc.validationErrors[index]
                            ? 'This field cannot be empty'
                            : null,
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8), // Space
      ],
    );
  }

  Widget _buildInputField() {
    return const TextField(
      decoration: InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Enter value',
      ),
    );
  }

  Widget _buildFooterText(Map<String, dynamic> component) {
    String footerText = component['text'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Footer Text:",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 4),

        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey), // Border color
            borderRadius: BorderRadius.circular(8), // Rounded corners
          ),
          padding: const EdgeInsets.symmetric(
              vertical: 4, horizontal: 14), // Padding inside the border
          child: TextField(
            controller:
                TextEditingController(text: footerText), // Set footer text
            readOnly: true, // Make it non-editable
            decoration: const InputDecoration(
              border: InputBorder.none, // Remove the border for the text field
            ),
          ),
        ),
        const SizedBox(height: 16), // Space between footer and buttons
      ],
    );
  }

  Widget _buildButtons(List<dynamic> buttons) {
    print('hoo there');
    final mc = Get.find<TemplateStuctureBottomSheetController>();
    int copyCount = 0;
    // return Text('data');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: buttons.asMap().entries.map((entry) {
        int index = entry.key; // Get the index
        var button = entry.value; // Get the button object

        //  buttons.map((button) {
        String buttonType = (button['type'] ?? 'default').toLowerCase();
        String buttonText = button['text'] ?? 'Button';
        String urlTemplate = button['url'] ?? '';
        List<String> variablePlaceholders = [];

        if (buttonType == 'url') {
          variablePlaceholders = _extractPlaceholders(urlTemplate);
          if (variablePlaceholders.isNotEmpty) {
            mc.isVaribleTemplete.value = true;
          }
          // if (mc.isButtonTemplateChange) {
          print('99999999999999');
          if (mc.dynamicUrlButtonTextControllers.isEmpty) {
            mc.initializeUrlControllers(variablePlaceholders);
          }
          // }
          mc.isButtonTemplateChange = false; 
        }

        if (buttonType == 'copy_code') {
          // if (mc.isButtonCCTemplateChange) {
          print(buttonType == 'copy_code');

          mc.initializeCopyCodeControllers(copyCount + 1);

          print('state hghj');
          // }
          mc.isButtonCCTemplateChange = false;
        }

        if (mc.isButtonTemplateChange) {
          print('is ima here');
          mc.clearUrlPreviousData();
        }

        if (mc.isButtonCCTemplateChange) {
          mc.clearCopyCodePreviousData();
        }

        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildButtonLabel(buttonType),
              const SizedBox(height: 4),
              if (buttonType == 'copy_code')
                _buildCopyCodeButton(button, copyCount + 1),
              if (buttonType == 'url')
                _buildUrlButton(urlTemplate, variablePlaceholders),
              if (buttonType != 'copy_code' && buttonType != 'url')
                _buildDefaultButton(buttonType, buttonText),
            ],
          ),
        );
      }).toList(),
    );
  }

// Function to extract URL placeholders
  List<String> _extractPlaceholders(String urlTemplate) {
    RegExp regExp = RegExp(r'\{\{(\d+)\}\}');
    return regExp
        .allMatches(urlTemplate)
        .map((match) => match.group(0) ?? '')
        .toList();
  }

// Function to build the label for each button
  Widget _buildButtonLabel(String buttonType) {
    return Text(
      '$buttonType BUTTON'.toUpperCase(),
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
        color: Colors.black54,
      ),
    );
  }

// Function to build the COPY_CODE button with input
  Widget _buildCopyCodeButton(Map<String, dynamic> button, int index) {
    index = index - 1;
    print('state  changed');
    String exampleCode = button['example']?.first ?? '';
    TextEditingController codeController = TextEditingController();
    final mc = Get.find<TemplateStuctureBottomSheetController>();
    if (mc.isButtonTemplateChange) {
      mc.clearCopyCodePreviousData();
    }
    mc.initializeCopyCodeControllers(index);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 300,
          child: Obx(() {
            return TextField(
              controller: mc.dynamicCopyCodeTextControllers[index],
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: exampleCode,
                errorText: mc.validationCopyCodeButtonErrors[index]
                    ? 'This field cannot be empty'
                    : null,
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildUrlButton(
      String urlTemplate, List<String> variablePlaceholders) {
    final mc = Get.find<TemplateStuctureBottomSheetController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Display the full URL
        SizedBox(
          width: 300,
          child: TextField(
            controller: TextEditingController(text: urlTemplate),
            readOnly: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Full URL',
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Display the dynamic variable input fields
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(), // Disable scrolling
          itemCount: variablePlaceholders.length,
          itemBuilder: (context, index) {
            String placeholder = variablePlaceholders[index];
            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Variable ${index + 1}:',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Obx(() {
                    return TextField(
                      controller: mc.dynamicUrlButtonTextControllers[index],
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: 'Enter value for $placeholder',
                        errorText: mc.validationButtonErrors[index]
                            ? 'This field cannot be empty'
                            : null,
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

// Function to build the URL button and its variable inputs
  Widget _buildUrlButtonold(
      String urlTemplate, List<String> variablePlaceholders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 300,
          child: TextField(
            controller: TextEditingController(text: urlTemplate),
            readOnly: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Full URL',
            ),
          ),
        ),
        ...variablePlaceholders.asMap().entries.map((entry) {
          int index = entry.key;
          String placeholder = entry.value;

          return Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Variable ${index + 1}:',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(
                  width: 300,
                  child: TextField(
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: 'Enter value for $placeholder',
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

// Function to build a default action button
  Widget _buildDefaultButton(String buttonType, String buttonText) {
    return ElevatedButton(
      onPressed: () {
        // Handle button actions based on type
        if (buttonType == 'action') {
          // Perform some action
        } else {
          print('Button pressed: $buttonText');
        }
      },
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(buttonText),
    );
  }

  //-------------------------------------------------------------------------------------

  Widget _buildTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 16,
      ),
    );
  }

  Widget _buildDropdownButton({
    required String hintText,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButton<String>(
      isExpanded: true,
      hint: Text(hintText),
      items: items,
      onChanged: onChanged,
    );
  }

  // Widget _buildSendButton() {
  //   return ElevatedButton(
  //     onPressed: () {
  //       // Logic to send the campaign
  //       print('Send button clicked');
  //     },
  //     child: Text('Send Campaign'),
  //   );
  // }

//   Widget buildTemplateUi(Map<String, dynamic> templateStructure) {
//     // Build your template UI based on the structure
//     return Column(
//       children: [
//         Text(templateStructure['HEADER'] ?? 'No Header'),
//         Text(templateStructure['BODY'] ?? 'No Body'),
//       ],
//     );
//   }
}
