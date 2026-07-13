import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getgabs/ui/pages/dashboard/chats/templates_folder/bottom_sheet/bottom_sheet_controller/bottom_sheet_controller.dart';
import 'package:getgabs/ui/pages/dashboard/chats/templates_folder/template_structure_bottom_sheet/template_structure_bottom_sheet.dart';
import 'package:getgabs/ui/pages/dashboard/chats/templates_folder/template_structure_bottom_sheet/template_stucture_bottom_sheet_controller.dart';

class BottomSheetWidget extends StatelessWidget {
  final BottomSheetController templateController =
      Get.put(BottomSheetController());

  BottomSheetWidget({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTitle('Send Campaign Individually'),
              const SizedBox(height: 16),
              _buildLabel('Choose Template'),
              _buildTemplateDropdown(context),
              _buildTemplateStructure(),
              _buildTemplateSelectionWarning(),
            ],
          ),
        ),
      ),
    );
  }

  // Title widget
  Widget _buildTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  // Label widget
  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(fontSize: 16),
    );
  }

  // Dropdown for selecting templates
  Widget _buildTemplateDropdown(BuildContext context) {
    return Obx(() {
      final dropdownItems = _buildDropdownItems();

      return _buildDropdownButton(
        hintText: templateController.selectedTamplate.value.isEmpty
            ? '--Select Template--'
            : templateController.selectedTamplate.value,
        items: dropdownItems,
        onChanged: (value) => _onTemplateChanged(value, context),
      );
    });
  }

  // Build dropdown items based on template controller's state
  List<DropdownMenuItem<String>> _buildDropdownItems() {
    final templates = templateController.availableTemplates;
    final dropdownItems = templates.map((template) {
      return DropdownMenuItem<String>(
        value: template,
        child: Text(template),
      );
    }).toList();

    if (templateController.isLoadingTemplates.value) {
      dropdownItems.add(_buildLoadingIndicator());
    } else if (templateController.canLoadMoreTemplates.value) {
      dropdownItems.add(_buildAddMoreButton());
    } else {
      dropdownItems.add(_buildNoMoreTemplatesMessage());
    }

    return dropdownItems;
  }

  // Handle template selection and open a new bottom sheet
  void _onTemplateChanged(String? value, BuildContext context) {
    if (value == null) return;

    templateController.isOptionSelected.value = true;
    templateController.isCarousal.value = false;

    if (value == 'add_more') {
      templateController.loadMoreMessageTemplates();
    } else {
      templateController.selectedTamplate.value = value;
      print(value);
      // You can add your template fetching logic here
      // templateController.fetchTemplateStructureApi(value);
      // templateController.fetchMessageTemplateJsonApi(value);

      // Open a new bottom sheet on template selection
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) {
          Get.put(TemplateStuctureBottomSheetController(value));

          return TemplateStructureBottomSheet();
        },
      ).whenComplete(() {
        // When the bottom sheet is dismissed, destroy the controller
        Get.delete<TemplateStuctureBottomSheetController>();
      });
    }
  }

  // Loading indicator for dropdown
  DropdownMenuItem<String> _buildLoadingIndicator() {
    return const DropdownMenuItem<String>(
      value: 'loading',
      enabled: false,
      child: Center(child: CircularProgressIndicator()),
    );
  }

  // Add more button for dropdown
  DropdownMenuItem<String> _buildAddMoreButton() {
    return const DropdownMenuItem<String>(
      value: 'add_more',
      child: Center(
        child: Text(
          '+ Add More',
          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  // No more templates message
  DropdownMenuItem<String> _buildNoMoreTemplatesMessage() {
    return const DropdownMenuItem<String>(
      value: 'no_more',
      enabled: false,
      child: Center(
        child: Text('No more templates', style: TextStyle(color: Colors.grey)),
      ),
    );
  }

  // Display template structure or loading indicator
  Widget _buildTemplateStructure() {
    return Obx(() {
      if (templateController.isTempStrucProgress.value) {
        return const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        );
      } else if (templateController.templateStructure.isNotEmpty) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: _buildTemplateUi(templateController.templateStructure),
        );
      } else if (templateController.errorMessage.isNotEmpty) {
        return Text(templateController.errorMessage.value);
      } else {
        return const SizedBox.shrink();
      }
    });
  }

  // Template UI Builder
  Widget _buildTemplateUi(Map<String, dynamic> templateStructure) {
    return Column(
      children: [
        Text(templateStructure['HEADER'] ?? 'No Header'),
        Text(templateStructure['BODY'] ?? 'No Body'),
      ],
    );
  }

  // Warning for template selection
  Widget _buildTemplateSelectionWarning() {
    return Obx(() {
      return templateController.isOptionSelected.value
          ? const SizedBox.shrink()
          : const Text(
              'Please Select Template',
              style: TextStyle(color: Colors.red),
            );
    });
  }
}


/*
class BottomSheetWidget extends StatelessWidget {
  final BottomSheetController controller = Get.put(BottomSheetController());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Bottom Sheet Example")),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              _buildHeader("Header Text"),
              SizedBox(height: 8),
              _buildBodyText({
                'text': 'Body Text with {{1}} and {{2}} placeholders.'
              }),
              SizedBox(height: 8),
              _buildFooterText({'text': 'Footer Text here'}),
              SizedBox(height: 8),
              _buildButtons([
                {'type': 'url', 'text': 'Visit Site', 'url': 'https://example.com/{{1}}'},
                {'type': 'copy_code', 'text': 'Copy Code', 'example': ['ABC123']}
              ]),
              SizedBox(height: 8),
              // _buildCarousel([
              //   {
              //     'components': [
              //       {'type': 'HEADER', 'text': 'Header 1'},
              //       {'type': 'BODY', 'text': 'This is the body content for card 1.'},
              //       {'type': 'BUTTONS', 'buttons': [{'type': 'action', 'text': 'Button 1'}]}
              //     ]
              //   },
              //   {
              //     'components': [
              //       {'type': 'HEADER', 'text': 'Header 2'},
              //       {'type': 'BODY', 'text': 'This is the body content for card 2.'},
              //       {'type': 'BUTTONS', 'buttons': [{'type': 'action', 'text': 'Button 2'}]}
              //     ]
              //   }
              // ])
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String headerText) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(headerText, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black54)),
        SizedBox(height: 3),
        _buildFileSelectionButton('Select Image', Icons.image, 'image')
      ],
    );
  }

  Widget _buildBodyText(Map<String, dynamic> component) {
    String bodyText = component['text'] ?? '';
    final controller = Get.find<BottomSheetController>();

    // Create a RegExp to find variable placeholders like {{1}}, {{2}}, etc.
    RegExp regExp = RegExp(r'\{\{(\d+)\}\}');
    List<InlineSpan> spans = [];
    int lastMatchEnd = 0;
    List<String> variablePlaceholders = [];

    for (final match in regExp.allMatches(bodyText)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: bodyText.substring(lastMatchEnd, match.start)));
      }

      String placeholder = match.group(0) ?? '';
      spans.add(TextSpan(
        text: placeholder,
        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
      ));
      variablePlaceholders.add(placeholder);
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < bodyText.length) {
      spans.add(TextSpan(text: bodyText.substring(lastMatchEnd)));
    }

    controller.initializeControllers(variablePlaceholders);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Body Text:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black54)),
        SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: EdgeInsets.all(16),
          child: RichText(
            text: TextSpan(
              style: TextStyle(color: Colors.black),
              children: spans,
            ),
          ),
        ),
        SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: variablePlaceholders.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Body Variable ${index + 1}:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Obx(() {
                    return TextField(
                      controller: controller.dynamicTextControllers[index],
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        errorText: controller.validationErrors[index]
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
        SizedBox(height: 8),
      ],
    );
  }

  Widget _buildFooterText(Map<String, dynamic> component) {
    String footerText = component['text'] ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Footer Text:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black54)),
        SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 14),
          child: TextField(
            controller: TextEditingController(text: footerText),
            readOnly: true,
            decoration: InputDecoration(border: InputBorder.none),
          ),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildButtons(List<dynamic> buttons) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: buttons.map((button) {
        String buttonType = (button['type'] ?? 'default').toLowerCase();
        String buttonText = button['text'] ?? 'Button';
        String urlTemplate = button['url'] ?? '';

        if (buttonType == 'url') {
          List<String> variablePlaceholders = _extractPlaceholders(urlTemplate);
          controller.initializeUrlControllers(variablePlaceholders);
          return _buildUrlButton(urlTemplate, variablePlaceholders);
        } else if (buttonType == 'copy_code') {
          return _buildCopyCodeButton(button, 1);
        } else {
          return _buildDefaultButton(buttonType, buttonText);
        }
      }).toList(),
    );
  }

  List<String> _extractPlaceholders(String urlTemplate) {
    RegExp regExp = RegExp(r'\{\{(\d+)\}\}');
    return regExp.allMatches(urlTemplate).map((match) => match.group(0) ?? '').toList();
  }

  Widget _buildCopyCodeButton(Map<String, dynamic> button, int index) {
    String exampleCode = button['example']?.first ?? '';
    controller.initializeCopyCodeControllers(index);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 300,
          child: Obx(() {
            return TextField(
              controller: controller.dynamicCopyCodeTextControllers[index - 1],
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: exampleCode,
                errorText: controller.validationCopyCodeButtonErrors[index - 1]
                    ? 'This field cannot be empty'
                    : null,
              ),
            );
          }),
        ),
        SizedBox(height: 8),
      ],
    );
  }

  Widget _buildUrlButton(String urlTemplate, List<String> variablePlaceholders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 300,
          child: TextField(
            controller: TextEditingController(text: urlTemplate),
            readOnly: true,
            decoration: InputDecoration(border: OutlineInputBorder(), labelText: 'Full URL'),
          ),
        ),
        SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: variablePlaceholders.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Variable ${index + 1}:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Obx(() {
                    return TextField(
                      controller: controller.dynamicButtonTextControllers[index],
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Enter value for ${variablePlaceholders[index]}',
                        errorText: controller.validationButtonErrors[index]
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
      child: Text(buttonText),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildCarousel(List<dynamic> cards) {
    PageController _pageController = PageController();
    var _currentPage = 0.obs;

    return Column(
      children: [
        SizedBox(
          height: 500,
          child: PageView.builder(
            controller: _pageController,
            itemCount: cards.length,
            onPageChanged: (index) {
              _currentPage.value = index;
            },
            itemBuilder: (context, index) {
              var card = cards[index];
              List<Widget> cardWidgets = [];
              for (var component in card['components']) {
                switch (component['type']) {
                  case 'HEADER':
                    cardWidgets.add(HeaderWidget(
                      component: component,
                      index: index,
                      cardLength: cards.length,
                    ));
                    break;
                  case 'BODY':
                    cardWidgets.add(_buildBodyText(component));
                    break;
                  case 'BUTTONS':
                    cardWidgets.add(_buildButtons(component['buttons']));
                    break;
                  default:
                    break;
                }
              }
              return SingleChildScrollView(
                child: Card(
                  margin: EdgeInsets.all(8),
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
        SizedBox(height: 8),
        Obx(() => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(cards.length, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage.value == index ? Colors.blue : Colors.grey,
                  ),
                );
              }),
            )),
        SizedBox(height: 8),
        Text(
          "Swipe to see more",
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildFileSelectionButton(String label, IconData icon, String fileType) {
    return ElevatedButton.icon(
      icon: Icon(icon),
      label: Text(label),
      onPressed: () {
        controller.selectFile(fileType);
      },
    );
  }
}
*/
