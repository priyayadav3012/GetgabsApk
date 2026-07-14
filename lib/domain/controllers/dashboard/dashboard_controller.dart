import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:getgabs/data/get_storage/get_storage.dart';
import 'package:getgabs/data/models/rolling_over_chat_model.dart';
import 'package:getgabs/domain/controllers/sockets/sockets_controller.dart';
import 'package:getgabs/domain/end_points/api_end_points.dart';
import 'package:getgabs/domain/services/remote_services/chat_service.dart';
import 'package:getgabs/domain/services/whtasapp_calling_service.dart';
import '../../../data/models/active_chat_model.dart';
import '../../../data/models/message_modal.dart';
import '../../services/notifications_service/notification_service.dart';

class DashboardController extends GetxController {
  // Observables
  var isSearching = false.obs;
  var tabIndex = 0;
  var currentPage = 1.obs;
  var isApiCallInProgress = false.obs;
  var isActiveApiInCall = true.obs;
  var isInActiveApiInCall = true.obs;
  var isRollingOverApiInCall = false.obs;
  var rollingOverCurrentPage = 1.obs;
  var searchCurrentPage = 1.obs;
  bool _callListenerInitialized = false;
  var tabBarIndex = 0;
  var isAddingCustomer = false.obs;

  // FocusNode and TextEditingController
  final FocusNode focusNode = FocusNode();
  final searchEditingController = TextEditingController().obs;

  // Scroll Controllers
  final ScrollController dashScrollController = ScrollController();
  final ScrollController rollingOverScrollController = ScrollController();

  // Lists
  RxList<Message> messageChatList = <Message>[].obs;
  RxList<Profile> activeProfileDetailsList = <Profile>[].obs;
  RxList<RollingOverChatModel> rollingOverProfileDetailsList =
      <RollingOverChatModel>[].obs;

  // Services and Data
  final ChatServices chatServices = ChatServices();
  GetStorageUserData userData = GetStorageUserData();
  NotificationService notificationService = NotificationService();

  /// Returns a valid /partners/ bearer token, using the cached one unless
  /// [forceRefresh] is set (used to retry once after an expired/rejected
  /// token) or none is cached yet.
  Future<String?> _getPartnerSessionToken({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await userData.getPartnerSessionToken();
      if (cached != null) return cached;
    }

    final apiKey = await userData.getApiKey();
    final response = await chatServices
        .getSessionTokenService({"apikey": apiKey, "api_key": apiKey});

    final token = response['access_token']?.toString();
    if (token == null || token.isEmpty) {
      debugPrint('❌ getSessionToken did not return access_token: $response');
      return null;
    }

    final expiresIn =
        int.tryParse(response['expires_in']?.toString() ?? '') ?? 86400;
    await userData.savePartnerSessionToken(token, expiresIn);
    return token;
  }

  /// Adds a new customer/WhatsApp chat via the partners/managechat API.
  /// Returns true on success so the caller can close its dialog.
  Future<bool> addCustomer({
    required String customerName,
    required String countryCode,
    required String whatsappNumber,
  }) async {
    if (customerName.trim().isEmpty || whatsappNumber.trim().isEmpty) {
      EasyLoading.showError('Please fill in all required fields',
          duration: const Duration(seconds: 5));
      return false;
    }

    isAddingCustomer.value = true;
    try {
      final profileNumber = '$countryCode$whatsappNumber';
      Map<String, String> fields = {
        "customer_name": customerName.trim(),
        "country_code": countryCode,
        "whatsapp_number": whatsappNumber.trim(),
        "profile_number": profileNumber,
      };

      var token = await _getPartnerSessionToken();
      if (token == null) {
        EasyLoading.showError(
            'Unable to add customer right now. Please try again.',
            duration: const Duration(seconds: 5));
        return false;
      }

      var value = await chatServices
          .addCustomerService({...fields, "token": token});

      // ✅ This API responds with {"success": ..., "msg": ...}, not the
      // {"status": ..., "message": ...} shape the rest of the app uses.
      //
      // Only retry with a freshly-fetched token when the failure actually
      // looks auth-related — otherwise a legitimate validation error (e.g.
      // "Number already exists") would trigger a pointless duplicate call.
      if (value['success'] != true) {
        final msg = value['msg']?.toString().toLowerCase() ?? '';
        final looksLikeAuthFailure = msg.contains('token') ||
            msg.contains('auth') ||
            msg.contains('unauthor');
        if (looksLikeAuthFailure) {
          token = await _getPartnerSessionToken(forceRefresh: true);
          if (token != null) {
            value = await chatServices
                .addCustomerService({...fields, "token": token});
          }
        }
      }

      if (value['success'] == true) {
        EasyLoading.showSuccess('Customer added to Rolling Over chats',
            duration: const Duration(seconds: 5));
        refreshRollingOverChatList(increment: 'replace');
        refreshActiveChatList(increment: 'replace');
        return true;
      } else {
        EasyLoading.showError(
            value['msg']?.toString() ?? 'Failed to add customer',
            duration: const Duration(seconds: 5));
        return false;
      }
    } catch (e) {
      debugPrint('❌ addCustomer error: $e');
      EasyLoading.showError('Something went wrong',
          duration: const Duration(seconds: 5));
      return false;
    } finally {
      isAddingCustomer.value = false;
    }
  }

  /// Initialize WhatsApp call listener for incoming calls
  Future<void> initCallListener() async {
    if (_callListenerInitialized) {
      debugPrint('📱 Call listener already initialized');
      return;
    }

    debugPrint('📱 Initializing call listener from Dashboard...');

    try {
      await WhatsAppCallingConfig.initializeCallListener();
      _callListenerInitialized = true;

      if (WhatsAppCallingConfig.isCallListenerActive()) {
        debugPrint('✅ Call listener is ACTIVE - Ready for incoming calls');
      } else {
        debugPrint('⚠️ Call listener initialization failed');
      }
    } catch (e) {
      debugPrint('❌ Error initializing call listener: $e');
    }
  }

  @override
  void onInit() async {
    super.onInit();

    // Initialize call listener for incoming calls
    initCallListener();

    dashScrollController.addListener(_scrollListener);
    rollingOverScrollController.addListener(_rollingOverScrollListner);
    Get.put(SocketsController());

    focusNode.addListener(() {
      isSearching.value = focusNode.hasFocus;
    });

    notificationService.requestNotificationPermission();
    try {
      await notificationService.initLocalNotifications();
    } catch (e) {
      debugPrint('❌ initLocalNotifications failed — continuing without it: $e');
    }
    notificationService.getDeviceToken();
    notificationService.setupInteractMessage();
    notificationService.onInitTopic();

    activeChatListApi();
    rollingOverChatListApi();
  }

  void _scrollListener() {
    if (dashScrollController.position.pixels >=
        dashScrollController.position.maxScrollExtent) {
      if (isSearching.value) {
        searchCustomer(searchEditingController.value.text);
      } else {
        activeChatListApi();
      }
    }
  }

  void _rollingOverScrollListner() {
    if (rollingOverScrollController.position.pixels >=
        rollingOverScrollController.position.maxScrollExtent) {
      if (isSearching.value) {
        searchCustomer(searchEditingController.value.text);
      } else {
        rollingOverChatListApi();
      }
    }
  }

  refreshActiveChatList({String increment = 'add'}) {
    isActiveApiInCall.value = true;
    isApiCallInProgress.value = false;
    isChatPageLoading.value = false;
    activeProfileDetailsList.clear();
    currentPage.value = 1;
    activeChatListApi(increment: increment);
  }

  refreshRollingOverChatList({String increment = 'add'}) {
    isInActiveApiInCall.value = true;
    isRollingOverApiInCall.value = false;
    rollingOverProfileDetailsList.clear();
    rollingOverCurrentPage.value = 1;
    rollingOverChatListApi(increment: increment);
  }

  /// The backend does not return either chat list sorted by recent
  /// activity, so a fresh fetch (initial load, pull-to-refresh, or a new
  /// page) can put an already-recent chat below older ones. Re-sorting
  /// client-side after every fetch keeps "most recent first" true even
  /// across a full refresh, not just the live socket/send-time bump.
  DateTime _parseUpdatedTime(String value) =>
      DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);

  void _sortActiveByRecency() {
    activeProfileDetailsList.sort((a, b) =>
        _parseUpdatedTime(b.updatedTime).compareTo(_parseUpdatedTime(a.updatedTime)));
  }

  void _sortRollingOverByRecency() {
    rollingOverProfileDetailsList.sort((a, b) =>
        _parseUpdatedTime(b.updatedTime).compareTo(_parseUpdatedTime(a.updatedTime)));
  }

  /// Moves [profileWaKey]'s chat to the top of whichever list (active or
  /// rolling-over) it currently belongs to and refreshes its timestamp —
  /// mirrors WhatsApp's "most recent activity floats to top" behavior for
  /// both sending and receiving a message. No-op if the chat isn't in
  /// either list (a brand-new incoming chat is created directly by the
  /// socket handler, which has extra fields — name/id — this doesn't).
  void bumpChatOnNewActivity(String profileWaKey, {String? updatedTime}) {
    final time = updatedTime ??
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    final activeIndex = activeProfileDetailsList
        .indexWhere((p) => p.profileWaKey == profileWaKey);
    if (activeIndex != -1) {
      final profile = activeProfileDetailsList.removeAt(activeIndex);
      activeProfileDetailsList.insert(0, profile.copyWith(updatedTime: time));
      return;
    }

    final rollingIndex = rollingOverProfileDetailsList
        .indexWhere((p) => p.profileWaKey == profileWaKey);
    if (rollingIndex != -1) {
      final profile = rollingOverProfileDetailsList.removeAt(rollingIndex);
      rollingOverProfileDetailsList.insert(
          0, profile.copyWith(updatedTime: time));
    }
  }

  void markChatAsRead(String profileWaKey) {
    final index = activeProfileDetailsList.indexWhere(
      (e) => e.profileWaKey == profileWaKey,
    );

    if (index != -1) {
      activeProfileDetailsList[index] =
          activeProfileDetailsList[index].copyWith(
        getPendingMsgCount: 0,
      );

      activeProfileDetailsList.refresh();
    }
  }

// var isChatPageLoading = false.obs;

// Future<void> activeChatListApi({String increment = 'add'}) async {

//   debugPrint('Active Chat List API called with increment: $increment');

//   // if (isApiCallInProgress.value) return;
//   if (isChatPageLoading.value) return;

//   isChatPageLoading.value = true;
//   // isApiCallInProgress.value = true;

//       debugPrint("Updated Chat List ${isChatPageLoading.value}");

//   try {

//     final userId = await userData.getLoggedInUserId();
//     final apiKey = await userData.getApiKey();
//     final userRole = await userData.getUserRole();
//     final parentUserId = await userData.getParentUserId();
//     final userPrivilage = await userData.getUserPrivilage();

//     Map data = {
//       "parent_user_id": parentUserId,
//       "current_user_id": userId.toString(),
//       "api_key": apiKey.toString(),
//       "current_user_role": userRole,
//       "session_type": "open",
//       "page": currentPage.toString(),
//       "paginate": "15",
//       "user_privilage": userPrivilage
//     };

//     Map<String, String> headers = {
//       "X-Client-GetGabs": apiKey.toString(),
//       "Content-Type": "application/json"
//     };

//     final value = await chatServices.activeChatList(
//       data,
//       headers: headers,
//     );

//     if (value['status']) {

//       EasyLoading.dismiss();

//       List<dynamic> profileData =
//           value['message']['data']['data'] ?? [];

//       List<Profile> newProfiles =
//           profileData.map((e) => Profile.fromJson(e)).toList();

//       if (increment == "replace") {
//       debugPrint("Updated Chat List replace");
//         /// FULL REPLACE (refresh case)
//         activeProfileDetailsList.assignAll(newProfiles);

//       } else {

//       debugPrint("Updated Chat List Add");
//         /// UPDATE EXISTING OR ADD NEW
//         for (var newProfile in newProfiles) {

//           int index = activeProfileDetailsList.indexWhere(
//               (old) =>
//                   old.profileWaKey ==
//                   newProfile.profileWaKey);

//           if (index != -1) {

//             /// UPDATE EXISTING PROFILE
//             activeProfileDetailsList[index] = newProfile;

//           } else {

//             /// ADD NEW PROFILE
//             activeProfileDetailsList.add(newProfile);

//           }
//         }
//       }

//       /// IMPORTANT
//       activeProfileDetailsList.refresh();

//       debugPrint(
//           "Updated Chat List Length: ${activeProfileDetailsList.length}");

//       if (profileData.isNotEmpty) {
//         currentPage++;
//       }

//     } else {

//       EasyLoading.showError(value['message']);

//     }

//   } catch (error, stackTrace) {

//     debugPrint('Error: $error');
//     debugPrint('Stack Trace: $stackTrace');

//   } finally {

//     isApiCallInProgress.value = false;
//     isActiveApiInCall.value = false;
//     isChatPageLoading.value = false;
// debugPrint("Updated Chat 11List ${isChatPageLoading.value}");
//     EasyLoading.dismiss();
//   }
// }
  var isChatPageLoading = false.obs;

  Future<void> activeChatListApi({String increment = 'add'}) async {
    debugPrint('Active Chat List API called with increment: $increment');
    if (isApiCallInProgress.value) return;
    isApiCallInProgress.value = true;
    isChatPageLoading.value = true;

    try {
      final userId = await userData.getLoggedInUserId();
      final apiKey = await userData.getApiKey();
      final userRole = await userData.getUserRole();
      final parentUserId = await userData.getParentUserId();
      final userPrivilage = await userData.getUserPrivilage();

      Map data = {
        "parent_user_id": userRole == "user" ? userId.toString() : parentUserId,
        "current_user_id": userId.toString(),
        "api_key": apiKey.toString(),
        "current_user_role": userRole,
        "session_type": "open",
        "page": currentPage.toString(),
        "paginate": "15",
        "user_privilage": userPrivilage
      };
      Map<String, String> headers = {
        "X-Client-GetGabs": apiKey.toString(),
        "Content-Type": "application/json"
      };

      chatServices.activeChatList(data, headers: headers).then((value) {
        if (value['status']) {
          debugPrint(
              'Active Chat List API called with pppppppppppppppppppppppppppppp: $increment');
          List<dynamic> profileData = value['message']['data']['data'] ?? [];
          debugPrint('Received profile data: ${profileData.toString()}');
          if (increment == "replace") {
            activeProfileDetailsList.assignAll(
                profileData.map((datas) => Profile.fromJson(datas)).toList());
          } else {
            activeProfileDetailsList.addAll(
                profileData.map((datas) => Profile.fromJson(datas)).toList());
          }
          _sortActiveByRecency();
          activeProfileDetailsList.refresh();

          if (profileData.isNotEmpty) {
            currentPage++;
          }
        } else {
          EasyLoading.showError(value['message']);
        }
        print(activeProfileDetailsList);
      }).onError((error, stackTrace) {
        print(error);
        print(stackTrace);
      }).whenComplete(() {
        isApiCallInProgress.value = false;
        isActiveApiInCall.value = false;
        isChatPageLoading.value = false;
      });
    } catch (error, stackTrace) {
      isApiCallInProgress.value = false;
      isActiveApiInCall.value = false;
      isChatPageLoading.value = false;
      print('Error: $error');
      print('Stack Trace: $stackTrace');
    }
  }

  Future<void> rollingOverChatListApi({String increment = 'add'}) async {
    isChatPageLoading.value = true;
    try {
      final userId = await userData.getLoggedInUserId();
      final apiKey = await userData.getApiKey();
      final userRole = await userData.getUserRole();
      final parentUserId = await userData.getParentUserId();
      final userPrivilage = await userData.getUserPrivilage();

      Map data = {
        "parent_user_id": parentUserId,
        "current_user_id": userId.toString(),
        "api_key": apiKey.toString(),
        "current_user_role": userRole,
        "session_type": "closed",
        "page": rollingOverCurrentPage.toString(),
        "user_privilage": userPrivilage
      };
      Map<String, String> headers = {
        "X-Client-GetGabs": apiKey.toString(),
        "Content-Type": "application/json"
      };

      if (isRollingOverApiInCall.value) return;
      isRollingOverApiInCall.value = true;

      await chatServices.activeChatList(data, headers: headers).then((value) {
        if (value['status']) {
          isInActiveApiInCall.value = false;
          List<dynamic> profileData = value['message']['data']['data'] ?? [];

          if (increment == "replace") {
            rollingOverProfileDetailsList.assignAll(profileData
                .map((datas) => RollingOverChatModel.fromJson(datas))
                .toList());
          } else {
            rollingOverProfileDetailsList.addAll(profileData
                .map((datas) => RollingOverChatModel.fromJson(datas))
                .toList());
          }
          _sortRollingOverByRecency();
          rollingOverProfileDetailsList.refresh();

          if (profileData.isNotEmpty) {
            rollingOverCurrentPage++;
          }
        } else {
          isInActiveApiInCall.value = false;
          EasyLoading.showError(value['message']);
        }
      }).whenComplete(() {
        isInActiveApiInCall.value = false;
        isChatPageLoading.value = false;
        isRollingOverApiInCall.value = false;
      });

      print(rollingOverProfileDetailsList);
    } catch (error, stackTrace) {
      isInActiveApiInCall.value = false;
      isChatPageLoading.value = false;
      isRollingOverApiInCall.value = false;
      print('Error: $error');
      print('Stack Trace: $stackTrace');
      EasyLoading.dismiss();
    }
  }

  Timer? _searchDebounce;

  String _lastSearch = '';

  void onSearchChanged(String value) {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 600), () async {
      final trimmed = value.trim();

      if (value.trim().isEmpty) {
        isSearching.value = false;

        /// reload original list
        if (tabBarIndex == 0) {
          await refreshActiveChatList(
            increment: 'replace',
          );
        } else {
          await refreshRollingOverChatList(
            increment: 'replace',
          );
        }
        return;
      }

      if (trimmed.length >= 3 && trimmed != _lastSearch) {
        _lastSearch = trimmed;

        if (tabBarIndex == 0) {
          await searchCustomer(trimmed);
        } else {
          await searchCustomer(
            trimmed,
            sessionType: 'close',
            barIndex: 1,
          );
        }
      }
    });
  }

  Future<void> searchCustomer(String serachText,
      {String sessionType = 'open', int barIndex = 0}) async {
    try {
      if (serachText.trim().isEmpty) return;

      final userId = await userData.getLoggedInUserId();
      final apiKey = await userData.getApiKey();
      final userRole = await userData.getUserRole();
      final parentUserId = await userData.getParentUserId();
      final userPrivilage = await userData.getUserPrivilage();

      Map data = {
        "parent_user_id": parentUserId,
        "current_user_id": userId.toString(),
        "api_key": apiKey.toString(),
        "current_user_role": userRole,
        "session_type": sessionType,
        "search": serachText,
        "page": "1", // ✅ FIXED
        "paginate": "15",
        // "page": searchCurrentPage.toString(),
        "user_privilage": userPrivilage
      };
      Map<String, String> headers = {
        "X-Client-GetGabs": apiKey.toString(),
        "Content-Type": "application/json"
      };
      if (barIndex == 0) {
        isActiveApiInCall.value = true;
      } else {
        isInActiveApiInCall.value = true;
      }

      final value = await chatServices.searchCustomer(data, headers: headers);
      if (value['status']) {
        if (barIndex == 0) {
          isActiveApiInCall.value = false;
        } else {
          isInActiveApiInCall.value = false;
        }
        print(value);
        List<dynamic> profileData = value['message']['data']['data'] ?? [];
        if (barIndex == 1) {
          print("Search55555555555_Result11: ${profileData.toString()}");
          rollingOverProfileDetailsList.assignAll(profileData
              .map((datas) => RollingOverChatModel.fromJson(datas))
              .toList());
          // refreshActiveChatList(increment: 'replace',);
        } else {
          print("Search55555555555_Result12: ${profileData.toString()}");
          activeProfileDetailsList.assignAll(
              profileData.map((datas) => Profile.fromJson(datas)).toList());
          // refreshRollingOverChatList(increment: 'replace',);
        }
      } else {
        if (barIndex == 0) {
          isActiveApiInCall.value = false;
        } else {
          isInActiveApiInCall.value = false;
        }
      }
      print(activeProfileDetailsList);
    } catch (error, stackTrace) {
      if (barIndex == 0) {
        isActiveApiInCall.value = false;
      } else {
        isInActiveApiInCall.value = false;
      }
      print('Error: $error');
      print('Stack Trace: $stackTrace');
    }
  }

  String replaceFirstTwoSpaces(String profileName) {
    List<String> parts = profileName.split(' ');
    if (parts.length >= 2) {
      profileName = parts.take(2).join('+');
    } else {
      profileName = "${parts[0]}_";
    }
    return profileName;
  }

  // FIXED: Only one updateIndex method
  void updateIndex(int index) {
    tabIndex = index;
    if (tabIndex == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {});
    }
    if (tabIndex == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {});
    }
    if (tabIndex == 2) {}
    update();
  }

  // FIXED: Only one onClose method
  @override
  void onClose() {
    dashScrollController.dispose();
    rollingOverScrollController.dispose();
    // Dispose call listener when dashboard closes
    GlobalCallListenerService.instance.dispose();
    _searchDebounce?.cancel();
    super.onClose();
  }
}
