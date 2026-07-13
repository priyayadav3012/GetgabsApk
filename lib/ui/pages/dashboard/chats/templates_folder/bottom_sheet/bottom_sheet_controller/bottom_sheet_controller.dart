import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getgabs/data/get_storage/get_storage.dart';
import 'package:getgabs/domain/services/remote_services/chat_service.dart';

class BottomSheetController extends GetxController {
  GetStorageUserData userData = GetStorageUserData();
  final ChatServices chatServices = ChatServices();

  @override
  void onInit() {
     print('template fetching');
    super.onInit();
    fetchMessageTemplates();
    print('template fetching');
  }

//--------------------------------------------------------------------------------
  var availableTemplates = <String>[].obs;
  var currentTemplatePage = 1.obs;
  var isLoadingTemplates = false.obs;
  var canLoadMoreTemplates = true.obs;
  var selectedTamplate = '--Choose Template--'.obs;
  var isOptionSelected = false.obs;

  Future<void> fetchMessageTemplates() async {
    debugPrint('Chat Api Hit 111');
    if (isLoadingTemplates.value || !canLoadMoreTemplates.value) return;
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
      "page": currentTemplatePage.value,
      "pagination": 10,
      "user_privilage": userPrivilage,
    };

    // Setting up headers
    Map<String, String> headers = {
      "X-Client-GetGabs": apiKey.toString(),
      "Content-Type": "application/json",
    };

    isLoadingTemplates.value = true;

    try {
      // Making the API request using chatServices
      chatServices
          .fetchTemplatesService(jsonData, headers: headers)
          .then((response) {
        if (response['status'] == true) {
          final List data = response['message']['data'];
          if (data.isEmpty) {
            canLoadMoreTemplates.value = false;
          } else {
            availableTemplates.addAll(data.map((item) {
              return item['template_name']?.toString() ?? '';
            }).where((templateName) => templateName.isNotEmpty));
          }
          currentTemplatePage.value++;
        } else {
          print('Failed to fetch templates55: ${response['message']}');
        }
      }).onError((error, stackTrace) {
        print('Error fetching templates: $error');
        print('Stack trace: $stackTrace');
      });
    } catch (error) {
      print('Exception: $error');
    } finally {
      isLoadingTemplates.value = false;
    }
  }

  Future<void> loadMoreMessageTemplates() async {
    debugPrint('Chat Api Hit 112');
    await fetchMessageTemplates();
  }

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
    debugPrint('Chat Api Hit 113');
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
    debugPrint('chat Api Hit 114');
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

  @override
  void onClose() {
    // TODO: implement onClose
    super.onClose();
    print('yesss closed');
  }
}
