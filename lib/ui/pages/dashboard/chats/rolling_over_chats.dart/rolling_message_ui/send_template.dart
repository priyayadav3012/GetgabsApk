import 'dart:io';
import 'package:path/path.dart' as path; // Import the 'path' package
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getgabs/ui/themes/themes.dart';
import '../../../../../../domain/controllers/dashboard/messages_page/messages_page_controller.dart';
// import '../../templates_folder/header_widget.dart';

void showSendTemplateBottomSheet() {
  final templateController = Get.find<MessagesPageController>();

  Get.bottomSheet(
    elevation: 0,
    isScrollControlled: true,
    ClipRRect(
      child: Padding(
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
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTitle('Send Campaign Individually'),
                const SizedBox(height: 16),
                _buildLabel('Choose Template'),
                // ADD THIS ENTIRE TextField WIDGET for searching
                TextField(
                  controller: templateController.searchTemplateController,
                  onChanged: (value) {
                    // Update the reactive search query as the user types
                    templateController.searchQuery.value = value;
                  },
                  decoration: InputDecoration(
                    hintText: 'Search Template...',
                    prefixIcon: const Icon(Icons.search),
                    // Add a clear button to the search field
                    suffixIcon:
                        Obx(() => templateController.searchQuery.value.isEmpty
                            ? const SizedBox.shrink()
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  // Call the clearSearch method in the controller
                                  templateController.clearSearch();
                                },
                              )),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.grey),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                ),
                const SizedBox(height: 8), // Added for spacing
Obx(() {
  final isCurrentlySearching =
      templateController.searchQuery.value.trim().isNotEmpty;
  final isLoading = templateController.isLoadingTemplates.value;
  final templates = templateController.availableTemplates;

  // --- STATE 1: Display a live search results list ---
  if (isCurrentlySearching) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: isLoading && templates.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ))
          : templates.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("No templates found."),
                  ))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: templates.length,
                  itemBuilder: (context, index) {
                    final templateName = templates[index];
                    return ListTile(
                      title: Text(templateName),
                      onTap: () {
                        templateController.isOptionSelected.value = true;
                        templateController.isCarousal.value = false;
                        debugPrint('Selected template: $templateName');

                        templateController.selectedTamplate.value = templateName;
                        templateController.fetchTemplateStructureApi(
                            templateController.selectedTamplate.value);

                        templateController.isTemplateSelectChange = true;
                        templateController.isButtonTemplateChange = true;
                        templateController.isButtonCCTemplateChange = true;
                        templateController.isHeaderTemplateChange = true;
                        templateController.isCarousalTemplateChange = true;
                        templateController.fetchMessageTemplateJsonApi(
                            templateController.selectedTamplate.value);

                        templateController.clearSearch();
                      },
                    );
                  },
                ),
    );
  }
  // --- STATE 2: Custom Expandable Dropdown ---
  else {
    return Column(
      children: [
        // Dropdown Header (clickable to expand/collapse)
        InkWell(
          onTap: () {
            templateController.isDropdownExpanded.value = 
                !templateController.isDropdownExpanded.value;
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    templateController.selectedTamplate.value,
                    style: const TextStyle(fontSize: 14, color: Colors.black),
                  ),
                ),
                Icon(
                  templateController.isDropdownExpanded.value
                      ? Icons.arrow_drop_up
                      : Icons.arrow_drop_down,
                  color: Colors.black,
                ),
              ],
            ),
          ),
        ),
        
        // Expandable List
        if (templateController.isDropdownExpanded.value)
          Container(
            constraints: const BoxConstraints(maxHeight: 300),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: templates.length + 
                  (isLoading ? 1 : (templateController.canLoadMoreTemplates.value ? 1 : 1)),
              itemBuilder: (context, index) {
                // Show templates
                if (index < templates.length) {
                  final templateName = templates[index];
                  return ListTile(
                    title: Text(templateName),
                    onTap: () {
                      templateController.isOptionSelected.value = true;
                      templateController.isCarousal.value = false;
                      debugPrint('Selected template: $templateName');

                      templateController.selectedTamplate.value = templateName;
                      templateController.fetchTemplateStructureApi(
                          templateController.selectedTamplate.value);

                      templateController.isTemplateSelectChange = true;
                      templateController.isButtonTemplateChange = true;
                      templateController.isButtonCCTemplateChange = true;
                      templateController.isHeaderTemplateChange = true;
                      templateController.isCarousalTemplateChange = true;
                      templateController.fetchMessageTemplateJsonApi(
                          templateController.selectedTamplate.value);

                      // Close the dropdown after selection
                      templateController.isDropdownExpanded.value = false;
                    },
                  );
                }
                // Show loading indicator
                else if (isLoading) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                // Show "Load More" button
                else if (templateController.canLoadMoreTemplates.value) {
                  return ListTile(
                    title: const Center(
                      child: Text(
                        '+ Show More',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    onTap: () {
                      // Load more without closing the dropdown
                      templateController.loadMoreMessageTemplates();
                    },
                  );
                }
                // Show "No more templates"
                else {
                  return const ListTile(
                    enabled: false,
                    title: Center(
                      child: Text(
                        'No more templates',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                }
              },
            ),
          ),
      ],
    );
  }
}),                Obx(() {
                  return templateController.isTempStrucProgress.value
                      ? const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()))
                      : templateController.templateStructure.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: buildTemplateUi(
                                  templateController.templateStructure),
                            )
                          : templateController.errorMessage.isNotEmpty
                              ? Text(templateController.errorMessage.value)
                              : const Text('');
                }),

                Obx(() {
                  return templateController.isOptionSelected.value
                      ? const Text('')
                      : const Text(
                          'Please Select Template',
                          style: TextStyle(color: Colors.red),
                        );
                }),
                Obx(() {
                  if (templateController.isCarousal.value) {
                    return const Center(
                        child: Text(
                      'Coming Soon',
                      style: TextStyle(
                          color: Colors.indigo,
                          fontWeight: FontWeight.bold,
                          fontSize: 22),
                    ));
                  } else {
                    return _buildSendButton();
                  }
                })
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _buildTitle(String title) {
  return Center(
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

Widget _buildLabel(String label) {
  return Text(
    label,
    style: const TextStyle(fontSize: 14, color: Colors.black),
  );
}

Widget _buildDropdownButton({
  required String hintText,
  required List<DropdownMenuItem<String>> items,
  required ValueChanged<String?> onChanged,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey),
    ),
    child: DropdownButton<String>(
      isExpanded: true,
      underline: const SizedBox(), // Remove the default underline
      hint: Text(
        hintText,
        style: const TextStyle(fontSize: 14, color: Colors.black),
      ),
      icon: const Icon(Icons.arrow_drop_down_sharp, color: Colors.black),
      items: items,
      onChanged: onChanged,
    ),
  );
}

Widget _buildTextField({
  required String labelText,
  required TextInputType keyboardType,
}) {
  return TextField(
    decoration: InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(fontSize: 14),
      contentPadding:
          const EdgeInsets.symmetric(vertical: 15.0, horizontal: 10.0),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      filled: true,
      fillColor: Colors.white,
    ),
    keyboardType: keyboardType,
  );
}

Widget _buildSendButton() {
  final mc = Get.find<MessagesPageController>();

  return Center(
    child: ElevatedButton(
      onPressed: () {
        if (mc.selectedTamplate.value == '--Choose Template--') {
          mc.isOptionSelected.value = false;
        } else {
          print(mc.dynamicTextControllers.length);
          print(mc.validationErrors.length);
          if (!mc.isVaribleTemplete.value) {
            mc.processAndSendTemplate();

            // Get.back();
            // Get.back(); // Goes back another screen
            mc.isTempStrucProgress.value = true;
          } else {
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
              mc.processAndSendTemplate();
              // mc.isTempStrucProgress.value=true;
              // Get.back();
              // Get.back(); // Goes back another screen
              mc.isTempStrucProgress.value = true;
            } else {
              print('There are validation errors.');
            }
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

//-------------------template-structure-------------------------------------------
Widget buildTemplateUi(RxMap<String, dynamic> templateData) {
  List<Widget> widgetList = [];
  print('yes yes yes');

  var mc = Get.find<MessagesPageController>();

  if (mc.isButtonTemplateChange) {
    print('is ima here');
    mc.clearUrlPreviousData();
  }

  if (mc.isButtonCCTemplateChange) {
    mc.clearCopyCodePreviousData();
  }
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
  var mc = Get.find<MessagesPageController>();
  if (mc.isHeaderTemplateChange) {
    print('99999999999999');
    mc.clearSelection();
    mc.validateImageSelctionError.value = false;
    mc.isHeaderType.value = '';
  }
  mc.isHeaderTemplateChange = false;

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
  final mc = Get.find<MessagesPageController>();

  // Sirf pehli baar ya template change pe pre-fill karo
  if (mc.isHeaderTemplateChange || mc.headerTextController.text.isEmpty) {
    mc.headerTextController.text = headerText;
  }

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Header Text",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: mc.headerTextController,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            hintText: 'Enter header text...',
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: 14,
            ),
          ),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

// Function to build an image header
Widget _buildImageHeader(String headerText) {
  var mc = Get.find<MessagesPageController>();
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
                fit: BoxFit.cover, // Options include cover, contain, fill, etc.
              ),
            ),
          );
          return Image.file(File(mc.selectedFilePath
              .value)); // No error message if a file is selected
        }
      }),
    ],
  );
}

// Function to build a video header
Widget _buildVideoHeader(String headerText) {
  var mc = Get.find<MessagesPageController>();

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
          return Image.file(File(mc.selectedFilePath
              .value)); // No error message if a file is selected
        }
      }),
    ],
  );
}

// Function to build a document header
Widget _buildDocumentHeader(String headerText) {
  var mc = Get.find<MessagesPageController>();

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
          return Image.file(File(mc.selectedFilePath
              .value)); // No error message if a file is selected
        }
      }),
    ],
  );
}

// Function to build the file selection button
Widget _buildFileSelectionButton(String text, IconData icon, String fileType) {
  var mc = Get.find<MessagesPageController>();
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
  final mc = Get.find<MessagesPageController>();

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
      spans.add(TextSpan(text: bodyText.substring(lastMatchEnd, match.start)));
    }
    // Add the placeholder text
    String placeholder = match.group(0) ?? '';
    spans.add(TextSpan(
      text: placeholder,
      style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.blue), // Style for the placeholder
    ));
    variablePlaceholders.add(placeholder); // Store the placeholder
    lastMatchEnd = match.end;
  }

  // Add the remaining text after the last match
  if (lastMatchEnd < bodyText.length) {
    spans.add(TextSpan(text: bodyText.substring(lastMatchEnd)));
  }
  print('hellow there');
  // Initialize dynamic text controllers based on variable placeholders
  if (mc.isTemplateSelectChange) {
    mc.initializeControllers(variablePlaceholders);
  }
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
  final mc = Get.find<MessagesPageController>();
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
        if (mc.isButtonTemplateChange) {
          print('99999999999999');
          mc.initializeUrlControllers(variablePlaceholders);
        }
        mc.isButtonTemplateChange = false;
      }

      if (buttonType == 'copy_code') {
        if (mc.isButtonCCTemplateChange) {
          print(buttonType == 'copy_code');

          mc.initializeCopyCodeControllers(copyCount + 1);

          print('state hghj');
        }
        mc.isButtonCCTemplateChange = false;
      }

      // if (mc.isButtonTemplateChange) {
      //   print('is ima here');
      //   mc.clearUrlPreviousData();
      // }

      // if (mc.isButtonCCTemplateChange) {
      //   mc.clearCopyCodePreviousData();
      // }

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
  final mc = Get.find<MessagesPageController>();
  // if (mc.isButtonTemplateChange) {
  //  mc. clearCopyCodePreviousData();
  // }
  // mc.initializeCopyCodeControllers(index);
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

Widget _buildUrlButton(String urlTemplate, List<String> variablePlaceholders) {
  final mc = Get.find<MessagesPageController>();

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
                    controller: mc.dynamicButtonTextControllers[index],
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

Widget _buildCarousel(List<dynamic> cards) {
  PageController pageController = PageController();
  var currentPage = 0.obs; // Track the current page index
  var mc = Get.find<MessagesPageController>();
  // if (mc.isCarousalTemplateChange) {}
  return Column(
    children: [
      SizedBox(
        height: 500, // Set height for carousel
        child: PageView.builder(
          controller: pageController,
          itemCount: cards.length,
          onPageChanged: (index) {
            // Update current page index when the page changes
            currentPage.value = index;
          },
          itemBuilder: (context, index) {
            var card = cards[index];
            List<Widget> cardWidgets = [];
            print(
                'flksdkfsdklfkjsdlfjlksdjflksdfkjsdlkfjsdlkjflksdjflkjsdflkj');
            print(index);
            // Loop through components within each card
            for (var component in card['components']) {
              // buildTemplateUi(component);
              switch (component['type']) {
                case 'HEADER':
                  //   // cardWidgets.add(_buildHeader(component));
                  // cardWidgets.add(HeaderWidget(
                  //   component: component,
                  //   index: index,
                  //   cardLength: cards.length,
                  // ));
                  break;
                case 'BODY':
                  cardWidgets.add(_buildBodyText(component));
                  break;
                case 'BUTTONS':
                  cardWidgets.add(_buildButtons(component['buttons']));
                  break;
                default:
                  // Handle other component types if necessary
                  break;
              }
            }
            return SingleChildScrollView(
              child: Card(
                margin: const EdgeInsets.all(8),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: cardWidgets,
                  ),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 8), // Space between carousel and indicator
      Obx(() => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(cards.length, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: currentPage.value == index
                      ? Colors.blue
                      : Colors.grey, // Change color based on active page
                ),
              );
            }),
          )),
      const SizedBox(height: 8), // Space between indicator and hint
      const Text(
        "Swipe to see more",
        style: TextStyle(
          fontSize: 16,
          color: Colors.black54,
        ),
      ),
    ],
  );
}
