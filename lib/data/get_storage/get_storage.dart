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

  /// Returns the general auth api_key (used for socket auth).
  /// Priority: top-level > facebook_details > getadmininfo
  // Future<String> getApiKey() async {
  //   try {
  //     final box = GetStorage();
  //     await box.initStorage;
  //     final storedDataJson = box.read('responseData');

  //     if (storedDataJson == null) {
  //       debugPrint('⚠️ getApiKey: responseData is null in storage');
  //       return '';
  //     }

  //     final Map<String, dynamic> storedData = json.decode(storedDataJson);

  //     // 1. Top-level api_key
  //     final topLevel = storedData['api_key']?.toString() ?? '';
  //     if (topLevel.isNotEmpty) {
  //       return topLevel;
  //     }

  //     // 2. facebook_details at root
  //     final key2 = _extractFbApiKey(storedData['facebook_details']);
  //     if (key2.isNotEmpty) return key2;

  //     // 3. getadmininfo (agent login response)
  //     final key3 = _extractAdminInfoApiKey(storedData['getadmininfo']);
  //     if (key3.isNotEmpty) return key3;

  //     return '';
  //   } catch (e) {
  //     debugPrint('❌ getApiKey error: $e');
  //     return '';
  //   }
  // }
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

      // Check facebook_details FIRST (priority) ✅
      final fbApiKey = storedData['facebook_details']?[0]?['api_key'];
      if (fbApiKey != null && fbApiKey.toString().isNotEmpty) {
        final apiKeyStr = fbApiKey.toString();
        debugPrint('📱 ApiKey from facebook_details: ${apiKeyStr.substring(0, 10)}...');
        return apiKeyStr;
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

      // Fallback - top-level api_key                                                                                                                                                                                                                                                                                                                                                    
      if (storedData['api_key'] != null && storedData['api_key'].toString().isNotEmpty) {
        final apiKey = storedData['api_key'].toString();
        debugPrint('📱 ApiKey from top-level: ${apiKey.substring(0, 10)}...');
        return apiKey;
      }
      
      debugPrint('⚠️ ApiKey not found in response data');
      debugPrint('📋 Available keys: ${storedData.keys.toList()}');
      return '';
    } catch (e) {
      debugPrint('❌ Error getting apiKey: $e');
      return '';
    }
  }
  
  /// Returns the WhatsApp Business API key used for CALLING.
  /// Only looks at facebook_details (NOT top-level api_key which is an auth token).
  /// Priority: facebook_details at root > getadmininfo.facebook_details
  Future<String> getWhatsAppBusinessApiKey() async {
    try {
      final box = GetStorage();
      await box.initStorage;
      final storedDataJson = box.read('responseData');

      if (storedDataJson == null) {
        debugPrint('⚠️ getWhatsAppBusinessApiKey: responseData is null');
        return '';
      }

      final Map<String, dynamic> storedData = json.decode(storedDataJson);

      // 1. facebook_details at root (admin login)
      final key1 = _extractFbApiKey(storedData['facebook_details']);
      if (key1.isNotEmpty) {
        debugPrint('📱 WA Business ApiKey from facebook_details');
        return key1;
      }

      // 2. getadmininfo (agent login — Map or List)
      final key2 = _extractAdminInfoApiKey(storedData['getadmininfo']);
      if (key2.isNotEmpty) {
        debugPrint('📱 WA Business ApiKey from getadmininfo.facebook_details');
        return key2;
      }

      debugPrint('⚠️ WA Business ApiKey not found. Keys: ${storedData.keys.toList()}');
      return '';
    } catch (e) {
      debugPrint('❌ getWhatsAppBusinessApiKey error: $e');
      return '';
    }
  }

  String _extractFbApiKey(dynamic fbDetails) {
    if (fbDetails is List && fbDetails.isNotEmpty) {
      return fbDetails[0]?['api_key']?.toString() ?? '';
    }
    return '';
  }

  String _extractAdminInfoApiKey(dynamic adminInfo) {
    if (adminInfo == null) return '';
    Map<String, dynamic>? adminMap;
    if (adminInfo is Map) {
      adminMap = Map<String, dynamic>.from(adminInfo);
    } else if (adminInfo is List && adminInfo.isNotEmpty) {
      adminMap = Map<String, dynamic>.from(adminInfo[0] as Map);
    }
    if (adminMap == null) return '';
    return _extractFbApiKey(adminMap['facebook_details']);
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

  //---------------------------Partners API session token---------------------------

  /// Caches the /partners/ bearer token with its expiry so getSessionToken
  /// only needs to be called again once it actually expires.
  Future<void> savePartnerSessionToken(String token, int expiresInSeconds) async {
    final box = GetStorage();
    await box.initStorage;
    final expiresAt = DateTime.now()
        .add(Duration(seconds: expiresInSeconds))
        .millisecondsSinceEpoch;
    box.write('partner_session_token', token);
    box.write('partner_session_token_expires_at', expiresAt);
  }

  /// Returns the cached bearer token, or null if missing/expired (leaving a
  /// 60s safety margin so a call doesn't start with a token that expires
  /// mid-request).
  Future<String?> getPartnerSessionToken() async {
    final box = GetStorage();
    await box.initStorage;
    final token = box.read('partner_session_token');
    final expiresAt = box.read('partner_session_token_expires_at');
    if (token == null || expiresAt == null) return null;
    final safeExpiry = DateTime.fromMillisecondsSinceEpoch(expiresAt as int)
        .subtract(const Duration(seconds: 60));
    if (DateTime.now().isAfter(safeExpiry)) return null;
    return token.toString();
  }

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
