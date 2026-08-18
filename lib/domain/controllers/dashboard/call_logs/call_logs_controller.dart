import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getgabs/data/get_storage/get_storage.dart';
import 'package:getgabs/data/models/call_log_model.dart';
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

  // Count of missed calls (across all pages fetched so far) the user
  // hasn't viewed yet — drives the header/bottom-nav badges.
  var totalMissedCalls = 0.obs;

  // Missed calls the user has already viewed (by call id) — excluded from
  // the count above so the badge doesn't reappear for the same calls after
  // a later page loads or a refresh re-fetches them. There's no backend
  // "mark as seen" endpoint yet, so this is a local/session-only ack, not
  // synced to `is_seen` on the server.
  final Set<String> _acknowledgedMissedCallIds = {};

  // Called when the user opens the Call Logs tab — mirrors WhatsApp's
  // Calls tab, where just viewing the list clears the unread-missed badge.
  void markMissedCallsAsSeen() {
    if (totalMissedCalls.value == 0) return;
    for (final raw in callLogs) {
      final entry = CallLogEntry.fromJson(raw);
      if (entry.isMissed && entry.id.isNotEmpty) {
        _acknowledgedMissedCallIds.add(entry.id);
      }
    }
    _recalculateMissedCounts();
  }

  void _recalculateMissedCounts() {
    int total = 0;
    for (final raw in callLogs) {
      final entry = CallLogEntry.fromJson(raw);
      if (entry.isMissed && !_acknowledgedMissedCallIds.contains(entry.id)) {
        total++;
      }
    }
    totalMissedCalls.value = total;
  }

  // Consecutive calls from the same number are folded into a single row,
  // same as WhatsApp's call log — e.g. three back-to-back missed calls from
  // one number show up as one entry with a "(3)" count, using the most
  // recent call's details (time/direction/duration) for display.
  //
  // NOTE: reads `callLogs` — call this from inside an Obx (or any reactive
  // scope) that also reads `callLogs`/`totalMissedCalls` so it recomputes
  // when the underlying data or the seen-state changes.
  List<CallLogGroup> get groupedCallLogs {
    final groups = <CallLogGroup>[];
    List<CallLogEntry> current = [];

    void flush() {
      if (current.isEmpty) return;
      groups.add(CallLogGroup(
        latest: current.first,
        callCount: current.length,
        entries: List.of(current),
      ));
      current = [];
    }

    for (final raw in callLogs) {
      final entry = CallLogEntry.fromJson(raw);
      if (current.isNotEmpty && current.last.phoneNumber == entry.phoneNumber) {
        current.add(entry);
      } else {
        flush();
        current = [entry];
      }
    }
    flush();
    return groups;
  }

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
        _recalculateMissedCounts();
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

// One row in the call log list — `latest` is the most recent call in the
// group, `callCount` is how many consecutive calls from that number were
// folded into it.
class CallLogGroup {
  final CallLogEntry latest;
  final int callCount;
  // Every call folded into this row (most recent first), so the row can
  // expand into an individual-call dropdown when tapped.
  final List<CallLogEntry> entries;

  CallLogGroup({
    required this.latest,
    required this.callCount,
    required this.entries,
  });
}
