import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class GetStorageUserData extends GetxController {
  Future<Map<String, dynamic>?> getUserDataInOneShot() async {
    final box = GetStorage();
    await box.initStorage;
    final storedDataJson = box.read('responseData');
    return storedDataJson != null
        ? Map<String, dynamic>.from(json.decode(storedDataJson))
        : null;
  }

  Future<bool> userDataStoreInOneShot(
      Map<String, dynamic> responseData, int userId) async {
    final box = GetStorage();
    await box.initStorage; // Start the storage drive

    final String responseDataJson = json.encode(responseData);
    box.write('id', userId);
    box.write('responseData', responseDataJson);

    return true;
  }

  Future<int> getLoggedInUserId() async {
    final box = GetStorage();
    await box.initStorage;
    final userId = box.read('id');
    if (userId == null) {
      debugPrint('⚠️ UserId is null in storage');
      return 0;
    }
    return userId is int ? userId : int.tryParse(userId.toString()) ?? 0;
  }

  Future<int> getUserPrivilage() async{
    final box = GetStorage();
    await box.initStorage;
    final storedDataJson = box.read('responseData');
    final Map<String, dynamic> storedData = json.decode(storedDataJson);
    return storedData['user_privilage'];
  }

  Future<String> getApiKey() async {
    try {
      final box = GetStorage();
      await box.initStorage;
      final storedDataJson = box.read('responseData');

      debugPrint('⚠️ ResponseData is null in storage for apiKey: $storedDataJson ${storedDataJson == null}');
      
      if (storedDataJson == null) {
        debugPrint('⚠️ ResponseData is null in storage');
        return '';
      }
      
      final Map<String, dynamic> storedData = json.decode(storedDataJson);

      // Check for top-level api_key first (priority)
      if (storedData['api_key'] != null && storedData['api_key'].toString().isNotEmpty) {
        final apiKey = storedData['api_key'].toString();
        debugPrint('📱 ApiKey from top-level: ${apiKey.substring(0, 10)}...');
        return apiKey;
      }

      // Check getadmininfo nested structure
      if (storedData['getadmininfo'] != null) {
        final apiKey = storedData['getadmininfo']['facebook_details']?[0]?['api_key'];
        if (apiKey != null && apiKey.toString().isNotEmpty) {
          final apiKeyStr = apiKey.toString();
          debugPrint('📱 ApiKey from getadmininfo: ${apiKeyStr.substring(0, 10)}...');
          return apiKeyStr;
        }
      }
      
      // Check facebook_details nested structure
      final apiKey = storedData['facebook_details']?[0]?['api_key'];
      if (apiKey != null && apiKey.toString().isNotEmpty) {
        final apiKeyStr = apiKey.toString();
        debugPrint('📱 ApiKey from facebook_details: ${apiKeyStr.substring(0, 10)}...');
        return apiKeyStr;
      }
      
      debugPrint('⚠️ ApiKey not found in response data');
      debugPrint('📋 Available keys: ${storedData.keys.toList()}');
      return '';
    } catch (e) {
      debugPrint('❌ Error getting apiKey: $e');
      return '';
    }
  }

  Future<String> getUserRole() async {
    final box = GetStorage();
    await box.initStorage;
    final storedDataJson = box.read('responseData');
    final Map<String, dynamic> storedData = json.decode(storedDataJson);
    return storedData['role'];
  }

  Future<String> getParentUserId() async {
    final box = GetStorage();
    await box.initStorage;
    final storedDataJson = box.read('responseData');
    if (storedDataJson == null) {
      debugPrint('⚠️ ResponseData is null in storage');
      return '';
    }
    try {
      final Map<String, dynamic> storedData = json.decode(storedDataJson);
      final parentUserId = storedData['parent_user_id'];
      if (parentUserId == null) {
        debugPrint('⚠️ ParentUserId is null in response data');
        return '';
      }
      return parentUserId.toString();
    } catch (e) {
      debugPrint('❌ Error parsing parentUserId: $e');
      return '';
    }
  }


  // Future<int> getLoginWithMobileNumberUser() async {
  //   final box = GetStorage();
  //   await box.initStorage;
  //   final userId = box.read('login_user_id');
  //   return userId;
  // }

  // Future<bool> saveLoginWithMobileNumberUser(int userId) async {
  //   final box = GetStorage();
  //   await box.initStorage; // Start the storage drive

  //   box.write('login_user_id', userId); // Store the user id

  //   return true;
  // }

  bool clearAllData() {
    try {
      GetStorage().erase();
      return true;
    } catch (e) {
      // print("Failed to clear data: $e");
      return false;
    }
  }

//---------------------------SingUp-User---------------------------

//   Future<bool> saveSignUpUser(int userId) async {
//     final box = GetStorage();
//     await box.initStorage; // Start the storage drive

//     box.write('user_id', userId); // Store the user id

//     return true;
//   }

//   Future<int> getSignUpUser() async {
//     final box = GetStorage();
//     await box.initStorage;
//     final userId = box.read('user_id');
//     return userId;
//   }

//   Future<bool> removeSignUpUser() async {
//     final box = GetStorage();
//     await box.initStorage; // Start the storage drive
// // Remove the 'user_id' key
//     box.remove('user_id');

//     return true;
//   }
  //-------------------------------------------------------
}
