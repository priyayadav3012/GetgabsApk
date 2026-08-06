import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getgabs/data/get_storage/get_storage.dart';
import 'package:getgabs/domain/services/remote_services/chat_service.dart';

class CallLogsController extends GetxController {
  final GetStorageUserData userData = GetStorageUserData();
  final ChatServices chatServices = ChatServices();

  final ScrollController scrollController = ScrollController();

  var callLogs = <Map<String, dynamic>>[].obs;
  var isLoading = false.obs; // first page
  var isLoadingMore = false.obs; // subsequent pages
  var error = ''.obs;
  var currentPage = 1.obs;
  var lastPage = 1.obs;
  bool _isApiCallInProgress = false;

  @override
  void onInit() {
    super.onInit();
    scrollController.addListener(_scrollListener);
    fetchCallLogs(page: 1);
  }

  @override
  void onClose() {
    scrollController.removeListener(_scrollListener);
    scrollController.dispose();
    super.onClose();
  }

  void _scrollListener() {
    if (!scrollController.hasClients) return;
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - 50) {
      if (!_isApiCallInProgress && currentPage.value < lastPage.value) {
        fetchCallLogs(page: currentPage.value + 1);
      }
    }
  }

  Future<void> refreshCallLogs() => fetchCallLogs(page: 1);

  Future<void> fetchCallLogs({int page = 1, int paginate = 20}) async {
    if (_isApiCallInProgress) return;
    _isApiCallInProgress = true;

    if (page == 1) {
      isLoading.value = true;
      error.value = '';
    } else {
      isLoadingMore.value = true;
    }

    try {
      final parentUserId = await userData.getParentUserId();
      final currentUserId = await userData.getLoggedInUserId();
      final apiKey = await userData.getApiKey();
      final userPrivilage = await userData.getUserPrivilage();
      final currentUserRole = await userData.getUserRole();

      final Map<String, dynamic> jsonData = {
        "parent_user_id": parentUserId.isEmpty ? '0' : parentUserId,
        "current_user_id": currentUserId.toString(),
        "api_key": apiKey,
        "current_user_role": currentUserRole,
        "user_privilage": userPrivilage,
        "paginate": paginate,
        "page": page,
      };

      final Map<String, String> headers = {
        "X-Client-GetGabs": apiKey.toString(),
        "Content-Type": "application/json",
      };

      final response =
          await chatServices.voiceCallLogsService(jsonData, headers: headers);
      debugPrint('📞 Call logs response: $response');

      if (response['status'] == true) {
        final Map<String, dynamic> paginator = response['data'];
        final List raw = paginator['data'] ?? [];

        currentPage.value = paginator['current_page'] ?? page;
        lastPage.value = paginator['last_page'] ?? currentPage.value;

        final parsed = raw.map((e) => Map<String, dynamic>.from(e)).toList();
        callLogs.value = page == 1 ? parsed : [...callLogs, ...parsed];
      } else {
        error.value =
            response['message']?.toString() ?? 'Failed to load call logs';
      }
    } catch (e) {
      debugPrint('❌ fetchCallLogs error: $e');
      error.value = 'Something went wrong';
    } finally {
      _isApiCallInProgress = false;
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }
}
