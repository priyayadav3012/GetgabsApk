import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:getgabs/data/get_storage/get_storage.dart';
import 'package:getgabs/domain/services/remote_services/chat_service.dart';
import 'package:image_picker/image_picker.dart';

class TemplateStuctureBottomSheetController extends GetxController {
  GetStorageUserData userData = GetStorageUserData();
  final ChatServices chatServices = ChatServices();
  String templateName;
  TemplateStuctureBottomSheetController(this.templateName);
  @override
  void onInit() {
    print('template fetching');
    super.onInit();
    fetchTemplateStructureApi(templateName);
    fetchMessageTemplateJsonApi(templateName);
    print('template fetching');
  }

  //---------------------------------text-editing-controllers----------------------------------------
  List<TextEditingController> dynamicTextControllers = [];
  List<TextEditingController> dynamicUrlButtonTextControllers = [];
  List<TextEditingController> dynamicCopyCodeTextControllers = [];

  var validationErrors = <bool>[].obs;
  var validationButtonErrors = <bool>[].obs;
  var validationCopyCodeButtonErrors = <bool>[].obs;

  // Method to initialize controllers for new templates
  void initializeControllers(List<String> variablePlaceholders) {
    //clearPreviousData(); // Clear previous data before initializing new ones

    for (int i = 0; i < variablePlaceholders.length; i++) {
      dynamicTextControllers.add(TextEditingController());
      validationErrors.add(false); // Initialize validation state
    }
  }

  // Initialize controllers based on the URL variable placeholders
  void initializeUrlControllers(List<String> variablePlaceholders) {
    clearUrlPreviousData(); // Clear previous data before initializing new ones

    for (int i = 0; i < variablePlaceholders.length; i++) {
      dynamicUrlButtonTextControllers.add(TextEditingController());
      validationButtonErrors.add(false); // Initialize validation state
    }
  }

  // Initialize controllers based on the URL variable placeholders
  void initializeCopyCodeControllers(int index) {
    // clearCopyCodePreviousData();
    index = index - 1;
    print(index);
    print('indexxxxxx');
    dynamicCopyCodeTextControllers.insert(index, TextEditingController());
    validationCopyCodeButtonErrors.insert(index, false);
  }

  // Method to validate inputs
  void validateInputs() {
    for (int i = 0; i < dynamicTextControllers.length; i++) {
      if (dynamicTextControllers[i].text.isEmpty) {
        validationErrors[i] = true; // Set error state if empty
      } else {
        validationErrors[i] = false; // Clear error state
      }
    }
  }

  // Validate URL input fields
  void validateUrlInputs() {
    for (int i = 0; i < dynamicUrlButtonTextControllers.length; i++) {
      if (dynamicUrlButtonTextControllers[i].text.isEmpty) {
        validationButtonErrors[i] = true; // Set error state if empty
      } else {
        validationButtonErrors[i] = false; // Clear error state
      }
    }
  }

  // Validate URL input fields
  void validateCopyCodeInputs() {
    for (int i = 0; i < dynamicCopyCodeTextControllers.length; i++) {
      if (dynamicCopyCodeTextControllers[i].text.isEmpty) {
        validationCopyCodeButtonErrors[i] = true; // Set error state if empty
      } else {
        validationCopyCodeButtonErrors[i] = false; // Clear error state
      }
    }
  }

  void clearBodyTextData() {
    for (var controller in dynamicTextControllers) {
      controller.dispose();
    }
    dynamicTextControllers.clear();
    if (validationButtonErrors.isNotEmpty) {
      validationErrors.clear();
    }
  }

  // Clear previous data for URL variables
  void clearUrlPreviousData() {
    for (var controller in dynamicUrlButtonTextControllers) {
      controller.dispose();
    }
    dynamicUrlButtonTextControllers.clear();
    if (validationButtonErrors.isNotEmpty) {
      validationButtonErrors.clear();
    }
  }

  // Clear previous data for URL variables
  void clearCopyCodePreviousData() {
    for (var controller in dynamicCopyCodeTextControllers) {
      controller.dispose();
    }
    dynamicCopyCodeTextControllers.clear();
    if (validationCopyCodeButtonErrors.isNotEmpty) {
      validationCopyCodeButtonErrors.clear();
    }
  }

  @override
  void onClose() {
    // clearBodyTextData();
    // clearUrlPreviousData();
    // clearCopyCodePreviousData();

    super.onClose();
    print('yesss closed');
  }

  //---------------------------------text-editing-controllers----------------------------------------

  //-------------------------------------------------------------------------
  var isHeaderType = ''.obs;

  var selectedFilePath = ''.obs; // Observable to track the file path
  var validateImageSelctionError = false.obs;

  final ImagePicker _picker = ImagePicker();

  Future<void> selectFile(String fileType) async {
    XFile? file;

    switch (fileType) {
      case 'image':
        file = await _picker.pickImage(source: ImageSource.gallery);
        if (file != null) {
          selectedFilePath.value = file.path; // Update with image path
        }
        break;

      case 'video':
        file = await _picker.pickVideo(source: ImageSource.gallery);
        if (file != null) {
          selectedFilePath.value = file.path; // Update with video path
        }
        break;

      case 'document':
        FilePickerResult? result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions:
              allowedExtensions, // Allowed file types for documents
        );
        if (result != null && result.files.single.path != null) {
          selectedFilePath.value =
              result.files.single.path!; // Update with document path
        }
        break;

      default:
        print('Unknown file type');
        return;
    }

    if (file == null && selectedFilePath.value.isEmpty) {
      print('No file selected');
    }

    // if (file != null) {
    //   selectedFilePath.value =
    //       file.path; // Update the observable with the selected file path
    // } else {
    //   print('No file selected');
    // }
  }

  bool isFileSelected() {
    return selectedFilePath.isNotEmpty; // Check if a file has been selected
  }

  void clearSelection() {
    selectedFilePath.value = ''; // Clear the file selection
  }

//docsssssssss

  //var selectedFilePath = ''.obs; // Reactive file path
  var allowedExtensions = [
    'pdf',
    'xlsx',
    'xls',
    'txt',
    'xlsm',
    'xlsb',
    'xltx',
    'doc',
    'docx',
    'csv',
    'avi',
    'ppt',
    'pptx',
    'avchd'
  ]; // Allowed file types

  Future<void> selectDocument() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions, // Restrict to allowed file types
    );

    if (result != null) {
      selectedFilePath.value = result.files.single.path!; // Get file path
      print('Selected file: ${selectedFilePath.value}');
    } else {
      // User canceled the picker
      print('No file selected');
    }
  }

  //--------------------------------------------------------------------------

//--------------------------------------------------------------------------------

  var templateStructurePage = 1.obs;
  // Map<String, dynamic> templateStructure = {};
  var templateStructure = <String, dynamic>{}.obs;
  var isTempStrucProgress = false.obs;
  var errorMessage = ''.obs;

  String tempStrucutureJsonString = '';
  var isTemplateSelectChange = false;
  var isButtonTemplateChange = false;
  var isButtonCCTemplateChange = false;
  var isHeaderTemplateChange = false;
  var isCarousalTemplateChange = false;
// Map<String, bool> formatTypes = {
//   'HEADER': false,
//   'BODY': false,
//   'FOOTER': false,
//   'BUTTONS': false,
//   'CAROUSEL': false,
// };
  var isCarousal = false.obs;
  Future<void> fetchTemplateStructureApi(String templateName) async {
    // isLoadingTemplates.value = true;

    // Fetching data from user preferences or service
    final parentUserId = await userData.getParentUserId();
    final currentUserId = await userData.getLoggedInUserId();
    final apiKey = await userData.getApiKey();
    final userPrivilage = await userData.getUserPrivilage();
    final roleOfUser = await userData.getUserRole();

    // Constructing the request body
    Map<String, dynamic> jsonData = {
      "parent_user_id": parentUserId,
      "current_user_id": currentUserId.toString(),
      "api_key": apiKey,
      "current_user_role": roleOfUser, // Assuming 'user' is constant
      "template_name": templateName,
      "page": templateStructurePage.value,
      "pagination": 10,
      "user_privilage": userPrivilage,
    };
    // Setting up headers
    Map<String, String> headers = {
      "X-Client-GetGabs": apiKey.toString(),
      "Content-Type": "application/json",
    };
    isTempStrucProgress.value = true;
    final response = await chatServices.fetchTemplateStructureService(jsonData,
        headers: headers);
    // print(response);

    try {
      // Making the API request using chatServices

      // print(response+"ffhgfjhfjfhhhfgjfhgfhg");
      if (response['error'] == false) {
        final data = response['data'];
        if (data.isNotEmpty) {
          print(data);
          final components =
              response['data'][0]['components']; // Extract components

          templateStructure.value = {
            'components': components,
            'name': data[0]['name'],
            'language': data[0]['language'],
          };
        } else {
          print('No data found for template: $templateName');
        }
      } else {
        templateStructure.value = {};

        errorMessage.value = 'Error fetching template structure';
        print('Error fetching template structure: ${response['error']}');
      }
    } catch (error, stackTrace) {
      print('Exception fetching template structure: $error $stackTrace');
    } finally {
      // isLoadingTemplates.value = false;
      isTempStrucProgress.value = false;
    }
  }

  var templateJsonPage = 1.obs;
  var templateJson = <String, dynamic>{}.obs;

  var isTempJsonProgress = false.obs;
  var errorJsonMessage = ''.obs;
  var isVaribleTemplete = false.obs;

  var senderNumber = '';
  Future<void> fetchMessageTemplateJsonApi(String templateName) async {
    final parentUserId = await userData.getParentUserId();
    final currentUserId = await userData.getLoggedInUserId();
    final apiKey = await userData.getApiKey();
    final userPrivilage = await userData.getUserPrivilage();
    final roleOfUser = await userData.getUserRole();

    Map<String, dynamic> jsonData = {
      "parent_user_id": parentUserId,
      "current_user_id": currentUserId.toString(),
      "api_key": apiKey,
      "current_user_role": roleOfUser,
      "template_name": templateName,
      "page": templateJsonPage.value,
      "pagination": 10,
      "user_privilage": userPrivilage,
    };

    Map<String, String> headers = {
      "X-Client-GetGabs": apiKey.toString(),
      "Content-Type": "application/json",
    };
    isTempJsonProgress.value = true;
    final response = await chatServices
        .fetchMessageTemplateJsonService(jsonData, headers: headers);
    // print(response);

    try {
      if (response['status']) {
        senderNumber = response['message']['sender'];
        templateJson.value = response['message']['template'];
      } else {
        templateJson.value = {};

        errorJsonMessage.value = 'Error fetching template structure';
        print('Error fetching template structure: ${response['error']}');
      }
    } catch (error, stackTrace) {
      print('Exception fetching template structure: $error $stackTrace');
    } finally {
      isTempJsonProgress.value = false;
    }
  }

//--------------------------------------------------------------------------------

  // // Handle loading templates from the API
  // void loadMoreMessageTemplates() {
  //   isLoadingTemplates.value = true;
  //   // Simulate a delay for loading
  //   Future.delayed(Duration(seconds: 2), () {
  //     isLoadingTemplates.value = false;
  //     availableTemplates.addAll(['Template 4', 'Template 5']);
  //     canLoadMoreTemplates.value = false; // No more templates available
  //   });
  // }

  // void fetchTemplateStructureApi(String template) {
  //   // Simulate API call for fetching template structure
  //   isTempStrucProgress.value = true;
  //   Future.delayed(Duration(seconds: 2), () {
  //     isTempStrucProgress.value = false;
  //     templateStructure.value = {
  //       'HEADER': 'Header for $template',
  //       'BODY': 'Body for $template'
  //     };
  //   });
  // }

  // void fetchMessageTemplateJsonApi(String template) {
  //   // Simulate API call for fetching the message template structure
  //   Future.delayed(Duration(seconds: 2), () {
  //     templateStructure.value = {
  //       'HEADER': 'Header for $template',
  //       'BODY': 'Body for $template'
  //     };
  //   });
  // }
}
