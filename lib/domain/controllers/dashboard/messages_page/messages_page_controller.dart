import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:getgabs/ui/pages/dashboard/chats/rolling_over_chats.dart/rolling_message_ui/reusable_widgets.dart';
import 'package:path/path.dart' as path; // Import the 'path' package

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getgabs/data/models/message_modal.dart';
import 'package:getgabs/domain/controllers/dashboard/dashboard_controller.dart';
import 'package:getgabs/domain/controllers/sockets/sockets_controller.dart';
import 'package:getgabs/domain/services/remote_services/chat_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../../../../data/get_storage/get_storage.dart';
import '../../../../data/models/active_chat_model.dart';
import '../../../../ui/pages/dashboard/chats/messages_ui/media_preview_page.dart';
import 'package:dio/dio.dart'; // For HTTP requests
import 'package:path_provider/path_provider.dart'; // For accessing local storage
import 'package:url_launcher/url_launcher.dart';

import '../../../../ui/pages/dashboard/chats/templates_folder/carousal/header_selection_controller.dart';
import '../../../../ui/res/utils/utils.dart';
import '../../../../ui/themes/themes.dart';

class MessagesPageController extends GetxController {
  var isSearching = false.obs;
  // late IO.Socket socket;
  var isAiPaused = false.obs;
  var isAiToggleLoading = false.obs;
 
  final ChatServices chatServices = ChatServices();
  GetStorageUserData userData = GetStorageUserData();

  // Sub-user (teammate) id -> display name, resolved from the same
  // "Assign to teammate" executive list — lets a sent message's
  // subuserSenderId be shown as the sender's name on the bubble, WATI/
  // Interakt-style, without the backend needing to add a name field to
  // every message payload.
  Map<int, String> agentNamesById = {};

  // The account-owning admin's own name (see GetStorageUserData.getAdminName)
  // — covers the one sender the executive list never contains: the owner
  // account itself, when it sends a message directly rather than via a
  // sub-user login.
  String adminName = '';

  // adminName resolves from local storage almost instantly, while
  // agentNamesById needs a network round-trip — without this flag, the
  // sender-name UI would treat that gap as "no teammate matched" and
  // wrongly flash the admin's name on every teammate's message until the
  // executive list finishes loading. Sender-name attribution (other than
  // "You", which never depends on this) waits for this to flip true.
  bool agentNamesLoaded = false;

  Future<void> _fetchAgentNames() async {
    try {
      adminName = await userData.getAdminName();
    } catch (e) {
      debugPrint('❌ getAdminName error: $e');
    }

    try {
      final dc = Get.find<DashboardController>();
      final token = await dc.getPartnerSessionToken();
      if (token != null && token.isNotEmpty) {
        final response = await chatServices.fetchExecutiveListService(token);
        if (response['status'] == true) {
          final list = response['ExecutiveList'] as List? ?? [];
          final Map<int, String> names = {};
          for (final u in list) {
            final id = int.tryParse(u['id'].toString());
            final name = u['name']?.toString() ?? '';
            if (id != null && name.isNotEmpty) names[id] = name;
          }
          agentNamesById = names;
        }
      }
    } catch (e) {
      debugPrint('❌ fetchAgentNames error: $e');
    }

    agentNamesLoaded = true;
    // groupedMessages itself is unchanged — refresh() just re-notifies its
    // listeners so the message list's Obx rebuilds and picks up the names.
    groupedMessages.refresh();
  }

  // Shared by the chat bubble's "You"/teammate-name attribution and the
  // Team Note card's header name — "You" when it's the currently logged-in
  // user's own message; else the teammate's name via the executive list;
  // else — the server only fills subuserSenderId for actual SUB-USER sends,
  // leaving it null/-1 for the admin/primary account's own sends — treat
  // "no sub-user matched" as "the admin sent this", showing "You" if the
  // viewer themself is that admin account, otherwise the admin's name.
  // Returns null while the executive list is still loading (rather than
  // guessing "admin" and flipping to the real name a moment later) or when
  // the message wasn't sent by this account at all.
  String? resolveSenderDisplayName(Message message) {
    if (!message.isSentByMe) return null;
    final isMe =
        message.subuserSenderId != null && message.subuserSenderId == userId;
    if (isMe) return 'You';
    if (!agentNamesLoaded) return null;

    final teammateName = agentNamesById[message.subuserSenderId];
    if (teammateName != null && teammateName.isNotEmpty) return teammateName;

    final viewerIsAdmin = adminId.isEmpty || adminId == '0';
    final name = viewerIsAdmin ? 'You' : adminName;
    return name.isEmpty ? null : name;
  }

  // The label shown above a QUOTED message inside a reply's little preview
  // box (WhatsApp-style: "You" / teammate name / customer name). A quoted
  // customer-sent message has no subuserSenderId to resolve — it's just
  // the chat's own customer, so use the profile name directly instead of
  // resolveSenderDisplayName (which only makes sense for our own sends).
  String resolveQuotedSenderName(Message quoted) {
    if (!quoted.isSentByMe) {
      final name = userProfile.value.profileName;
      return name.isNotEmpty ? name : 'Customer';
    }
    return resolveSenderDisplayName(quoted) ?? 'Reply';
  }

  // Tap-to-scroll (WhatsApp-style: tapping a reply's quoted preview jumps
  // to the original message). Each message row registers a GlobalKey
  // here as it builds (see messages_page.dart's itemBuilder); scrolling
  // only works while that key's context is actually mounted — a message
  // far enough away to not be built yet (e.g. on an unloaded older page)
  // can't be jumped to without a positioned-list package, so that case is
  // reported rather than silently doing nothing.
  final Map<String, GlobalKey> _messageKeys = {};

  GlobalKey keyForMessage(String messageId) {
    return _messageKeys.putIfAbsent(messageId, () => GlobalKey());
  }

  // Briefly highlighted after a successful scroll-to-quoted-message (see
  // scrollToMessage), read by the message row wrapper to flash a
  // background tint — the same "found it" cue WhatsApp gives. Not tied to
  // a plain tap on any message — only tapping a reply's quoted box (which
  // scrolls to the original) triggers this.
  var highlightedMessageId = ''.obs;

  // Guards against overlapping ensureVisible animations — tapping again
  // while one is still running is what made repeated taps feel
  // inconsistent (a second animation starting mid-flight fights the
  // first one instead of just being ignored).
  bool _isScrollingToMessage = false;

  Future<void> scrollToMessage(String messageId) async {
    if (_isScrollingToMessage) return;

    // TEMP DEBUG — remove once the "notes don't scroll" mystery is solved.
    debugPrint('🔎 scrollToMessage: looking for "$messageId"');
    debugPrint('🔎 scrollToMessage: known keys = ${_messageKeys.keys.toList()}');
    debugPrint('🔎 scrollToMessage: messageChatList ids = '
        '${messageChatList.map((m) => "${m.messageType}:${m.messageId}").toList()}');

    final context = _messageKeys[messageId]?.currentContext;
    if (context == null) {
      Get.snackbar(
        '',
        '',
        titleText: const SizedBox.shrink(),
        messageText: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.appThemeColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                color: AppTheme.appThemeColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Message isn't loaded yet — scroll up to find it",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFF2B2B2B),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderRadius: 14,
        duration: const Duration(seconds: 2),
        forwardAnimationCurve: Curves.easeOutCubic,
        reverseAnimationCurve: Curves.easeInCubic,
        animationDuration: const Duration(milliseconds: 280),
        boxShadows: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      );
      return;
    }

    _isScrollingToMessage = true;
    try {
      await Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );

      highlightedMessageId.value = messageId;
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (highlightedMessageId.value == messageId) {
          highlightedMessageId.value = '';
        }
      });
    } finally {
      _isScrollingToMessage = false;
    }
  }

  var isDropdownExpanded = false.obs;
final TextEditingController headerTextController = TextEditingController();
  // User info - initialized in onInit
  late String role;
  late int userId;
  late String adminId;

  RxList<Message> messageChatList = <Message>[].obs;
  var activeState = 'active'.obs;

  void updateState(String newState) {
    activeState.value = newState;
  }

  bool shouldContinue = true;

  Future<void> pickMediaOrDocument(ImageSource? source, String key,
      {bool isVideo = false,
      bool isDocument = false,
      bool isImage = false}) async {
    List<File> pickedFiles = [];
    EasyLoading.show();
    if (!shouldContinue) return;

    if (isDocument || isVideo || isImage) {
      // Use FilePicker for selecting multiple documents or videos
      FilePickerResult? result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: isVideo
            ? FileType.video
            : isImage
                ? FileType.image
                : FileType.any, // Set FileType based on the selection
      );
      if (!shouldContinue) return;

      if (result != null && result.files.length <= 10) {
        pickedFiles = result.files.map((file) => File(file.path!)).toList();
      } else if (result != null) {
        ReusableWidgets.snackBar(
            "Limit Exceeded", "You can select a maximum of 10 files.");
        EasyLoading.dismiss();

        // Get.snackbar("Limit Exceeded", "You can select a maximum of 10 files.");
        return; // Exit the function if the limit is exceeded
      }
    }

    //  else {
    //   // Use ImagePicker for selecting multiple images
    //  // final picker = ImagePicker();
    //   //final pickedMediaFiles = await picker.pickMultiImage();
    //       FilePickerResult? pickedMediaFiles = await FilePicker.platform.pickFiles(
    //     allowMultiple: true,
    //     type: FileType.image, // Set FileType based on the selection
    //   );
    //   if (!shouldContinue) return;

    //   if (pickedMediaFiles != null && pickedMediaFiles.files.length <= 10) {
    //     pickedFiles = pickedMediaFiles.files.map((file) => File(file.path!)).toList();
    //   } else if (pickedMediaFiles != null) {
    //     // Get.snackbar("Limit Exceeded", "You can select a maximum of 10 images.");
    //   ReusableWidgets.snackBar(
    //       "Limit Exceeded", "You can select a maximum of 10 files.");
    //   }
    //   EasyLoading.dismiss();

    //   return; // Exit the function if the limit is exceeded

    // }

    // Enforce file size limits
    const maxSizeImage = 4 * 1024 * 1024; // 4 MB
    const maxSizeVideo = 16 * 1024 * 1024; // 16 MB
    const maxSizeDocument = 100 * 1024 * 1024; // 100 MB

    pickedFiles = pickedFiles.where((file) {
      if (!shouldContinue) return false;

      int fileSize = file.lengthSync();
      bool isValidSize = true;

      if (isDocument) {
        isValidSize = fileSize <= maxSizeDocument;
      } else if (isVideo) {
        isValidSize = fileSize <= maxSizeVideo;
      } else {
        isValidSize = fileSize <= maxSizeImage;
      }

      if (!isValidSize) {
        // Utils.snackBar("File Too Large", "One or more files exceed the size limit.");
        ReusableWidgets.snackBar(
            "File Too Large", "One or more files exceed the size limit.");
        EasyLoading.dismiss();

        // Get.snackbar("File Too Large", "One or more files exceed the size limit.");
      }
      return isValidSize;
    }).toList();

    if (pickedFiles.isNotEmpty) {
      debugPrint('yess multiple');
      // Send each selected file to the preview page
      // for (var pickedFile in pickedFiles) {
      Get.to(() => MediaPreviewPage(
            files: pickedFiles,
            isDocument: isDocument,
            onSend: (caption) {
              for (var file in pickedFiles) {
                if (!shouldContinue) return;

                final type = isDocument
                    ? 'document'
                    : (_isVideoFile(file) ? 'video' : 'image');
                sendMediaMessage(
                  key,
                  file.path,
                  type,
                  caption,
                  _isVideoFile(file),
                  isDocument,
                );
              }
            },
          ));
      // }
    }
    EasyLoading.dismiss();
  }

  bool _isVideoFile(File file) {
    final extension = path.extension(file.path).toLowerCase();
    return extension == '.mp4' || extension == '.mov' || extension == '.avi';
  }

  //-------------------------------------------------------------------------
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
        debugPrint('Unknown file type');
        return;
    }

    if (file == null && selectedFilePath.value.isEmpty) {
      debugPrint('No file selected');
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
      debugPrint('Selected file: ${selectedFilePath.value}');
    } else {
      // User canceled the picker
      debugPrint('No file selected');
    }
  }

  //--------------------------------------------------------------------------

  var currentPage = 1.obs;
  bool isLoading = false;
  bool hasMoreMessages = true;
  String profileWaKey;
  int profileWaId;
  // Profile userProfile;
  var isScreen = '';
  String replaceFirstTwoSpaces(String profileName) {
    List<String> parts = profileName.split(' ');

    // Take only the first two words and replace the space with '+'
    if (parts.length >= 2) {
      // Join the first two words with '+'
      profileName = parts.take(2).join('+');
    } else {
      // If there's only one word, return it as is
      profileName = "${parts[0]}_";
      // profileName = parts.take(1).join('+');
    }

    return profileName;
  }

  Rx<Profile> userProfile; // Reactive Profile

  MessagesPageController(
      this.profileWaKey, this.profileWaId, this.isScreen, Profile userProfile)
      : userProfile = userProfile.obs; // Initialize as reactive

  // MessagesPageController(this.profileWaKey, this.profileWaId, this.isScreen, this.userProfile);

  final ScrollController scrollController = ScrollController();

  // Socket.IO retired for chat (see DashboardBinding) — no longer registered,
  // so this stays null and every use below is guarded accordingly. New
  // messages now arrive via FCM (NotificationService.firebaseInit()), which
  // delivers directly into the open chat the same way this used to.
  SocketsController? _socketsController;

  @override
  void onInit() {
    super.onInit();

    // Register as the open chat IMMEDIATELY and synchronously, before any
    // await — so incoming socket messages are delivered live even if the
    // initial API setup below is still running or fails. (Previously this
    // happened only at the end of the async setup, so any earlier throw left
    // the chat unregistered and live delivery silently dead.)
    if (Get.isRegistered<SocketsController>()) {
      _socketsController = Get.find<SocketsController>();
      _socketsController?.registerOpenChat(this);
    } else {
      debugPrint('SocketsController not registered when opening chat!');
    }

    // Initialize user info first to avoid race conditions
    _initializeUserInfoAndSetup();

    // userData.clearAllData();
    debounce(searchQuery, (_) => searchTemplates(),
        time: const Duration(milliseconds: 500));
  }

  /// Initialize user info and then register socket listeners
  Future<void> _initializeUserInfoAndSetup() async {
    try {
      // Step 1: Initialize user info
      await _initializeUserInfo();
      debugPrint('✅ User info initialized - ready for socket events');

      // Step 2: Only AFTER user info is ready, set up dashboard callbacks
      final dc = Get.find<DashboardController>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        dc.markChatAsRead(profileWaKey);
        dc.refreshActiveChatList(increment: 'replace');
        // dc.activeChatListApi(increment: "replace"); // optional sync with server
      });

      // Step 3: Load chats and templates
      await loadChatsApi(userKey: profileWaKey, from: 'outside');
      fetchMessageTemplates();
      _fetchAgentNames();

      scrollController.addListener(_scrollListener);
      messageChatList.listen((_) {
        groupedMessages.assignAll(groupMessagesByDate(messageChatList));
      });

      // Open-chat registration already happened synchronously in onInit
      // (guarded there — SocketsController may not be registered at all now
      // that chat has moved to FCM).

      WidgetsBinding.instance.addPostFrameCallback((_) {
        var dc = Get.find<DashboardController>();
        dc.focusNode.unfocus(); // Prevent focus on load
      });

      // Safety net: sockets can silently miss a "delivered"/"read" event
      // (app backgrounded, brief disconnect, etc.) leaving a tick stuck
      // forever until the chat is reopened. Periodically reconcile with
      // the server while the chat is open so it self-heals instead.
      _startStatusResync();
    } catch (e) {
      debugPrint('❌ Error in onInit setup: $e');
    }
  }

  Timer? _statusResyncTimer;

  void _startStatusResync() {
    _statusResyncTimer?.cancel();
    // Only fires the network call when a message is actually still pending
    // a final status (see the hasPending guard below), so a short interval
    // here is cheap and makes the fallback path feel near-instant.
    _statusResyncTimer =
        Timer.periodic(const Duration(seconds: 3), (_) {
      _resyncPendingMessageStatuses();
    });
  }

  void _stopStatusResync() {
    _statusResyncTimer?.cancel();
    _statusResyncTimer = null;
  }

  /// Re-checks delivery status for our own messages that aren't at a final
  /// state ('read'/'failed') yet, merging fresh statuses into the local
  /// list by messageId without disturbing pagination or scroll position.
  Future<void> _resyncPendingMessageStatuses() async {
    final hasPending = messageChatList.any((m) {
      final status = m.deliveryStatus?.toLowerCase();
      return m.isSentByMe && status != 'read' && status != 'failed';
    });
    if (!hasPending || isApiCallInProgress) return;

    try {
      final parentUserId = await userData.getParentUserId();
      final currentUserId = await userData.getLoggedInUserId();
      final apiKey = await userData.getApiKey();
      final currentUserRole = await userData.getUserRole();
      final userPrivilage = await userData.getUserPrivilage();

      Map data = {
        "parent_user_id": parentUserId,
        "current_user_id": currentUserId,
        "api_key": apiKey,
        "customer_key": profileWaKey,
        "current_user_role": currentUserRole,
        "page": "1",
        "user_privilage": userPrivilage
      };
      Map<String, String> headers = {
        "X-Client-GetGabs": apiKey.toString(),
        "Content-Type": "application/json"
      };

      final value = await chatServices.loadChats(data, headers: headers);
      if (value['status'] != true) return;

      final List<dynamic> freshList = value['message']['data']['data'] ?? [];
      bool changed = false;
      for (final raw in freshList) {
        final fresh = Message.fromJson(raw);
        final index = messageChatList
            .indexWhere((msg) => msg.messageId == fresh.messageId);
        if (index == -1) continue;
        final current = messageChatList[index];
        final statusChanged = current.deliveryStatus?.toLowerCase() !=
            fresh.deliveryStatus?.toLowerCase();
        // Backfill the real server id for our own just-sent messages (they
        // start at id 0 until confirmed) so they take their correct place in
        // the id-ordered sequence, even if the send response didn't return it.
        final needsId = current.id <= 0 && fresh.id > 0;
        if (statusChanged || needsId) {
          messageChatList[index] = current.copyWith(
            deliveryStatus: statusChanged ? fresh.deliveryStatus : null,
            id: needsId ? fresh.id : null,
          );
          changed = true;
        }
      }

      if (changed) {
        groupedMessages.assignAll(groupMessagesByDate(messageChatList));
      }
    } catch (e) {
      debugPrint('⚠️ Status resync error: $e');
    }
  }

  /// Initialize user information once at startup
  Future<void> _initializeUserInfo() async {
    try {
      role = await userData.getUserRole();
      userId = await userData.getLoggedInUserId();
      adminId = await userData.getParentUserId();
      debugPrint('✅ User info initialized - role: $role, userId: $userId, adminId: $adminId');
    } catch (e) {
      debugPrint('❌ Error initializing user info: $e');
    }
  }
  

  void openDialPad({required String url}) async {
    var androidUrl = Uri.parse(url);

    var iosUrl = Uri.parse(url);

    if (Platform.isIOS) {
      if (await canLaunchUrl(iosUrl)) {
        await launchUrl(iosUrl);
      } else {
        Utils.snackBar("Not Found", "Error While Launching");
      }
    } else {
      if (await canLaunchUrl(androidUrl)) {
        await launchUrl(androidUrl);
      } else {
        Utils.snackBar("Not Found", "Error While Launching");
      }
    }
  }
void toggleAiPause() async {
    if (isAiToggleLoading.value) return; // prevent double tap
    isAiToggleLoading.value = true;

    final bool newState = !isAiPaused.value; // true = AI paused, false = AI resumed

    try {
      final parentUserId = await userData.getParentUserId();
      final currentUserId = await userData.getLoggedInUserId();
      final apiKey = await userData.getApiKey();
      final userPrivilage = await userData.getUserPrivilage();
      final currentUserRole = await userData.getUserRole();

      Map<String, dynamic> jsonData = {
        "parent_user_id": parentUserId,
        "current_user_id": currentUserId,
        "api_key": apiKey,
        "customer_key": profileWaKey,
        "current_user_role": currentUserRole,
        "user_privilage": userPrivilage,
        "is_handed_off": newState, // true = AI paused, false = AI resumed
      };

      Map<String, String> headers = {
        "X-Client-GetGabs": apiKey.toString(),
        "Content-Type": "application/json",
      };

      debugPrint('Toggling handoff → is_handed_off: $newState');

      final response = await chatServices.toggleHandoffService(
        jsonData,
        headers: headers,
      );

      debugPrint('Toggle handoff response: $response');

      if (response['status'] == true) {
        // ✅ Success — update local state only after API confirms
        isAiPaused.value = newState;

        Get.snackbar(
          isAiPaused.value ? '⏸ AI Paused' : '▶ AI Resumed',
          isAiPaused.value
              ? 'AI auto-reply is paused for this chat.'
              : 'AI auto-reply is active for this chat.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
          backgroundColor: isAiPaused.value
              ? const Color(0xFFFF5722)
              : const Color(0xFF2196F3),
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
          borderRadius: 10,
          icon: Icon(
            isAiPaused.value ? Icons.pause_circle : Icons.play_circle,
            color: Colors.white,
          ),
        );
      } else {
        // ❌ Failed — keep original state, show error
        debugPrint('Toggle handoff failed: $response');
        ReusableWidgets.snackBar(
          "Error",
          response['message']?.toString() ?? "Failed to update AI status.",
        );
      }
    } catch (e) {
      debugPrint('Toggle handoff error: $e');
      ReusableWidgets.snackBar(
          "Error", "Something went wrong. Please try again.");
    } finally {
      isAiToggleLoading.value = false;
    }
  }

  var isUpdatingCustomerName = false.obs;

  /// Renames the customer whose chat is currently open — delegates to
  /// DashboardController so the chat list (active/rolling-over) picks up
  /// the new name too, then reflects it on this screen's own header.
  Future<bool> updateCustomerName(String newName) async {
    if (isUpdatingCustomerName.value) return false;
    isUpdatingCustomerName.value = true;
    try {
      if (!Get.isRegistered<DashboardController>()) return false;
      final ok = await Get.find<DashboardController>().updateCustomerName(
        profileWaKey: profileWaKey,
        newName: newName,
      );
      if (ok) {
        userProfile.value = userProfile.value.copyWith(profileName: newName);
      }
      return ok;
    } finally {
      isUpdatingCustomerName.value = false;
    }
  }

 var shortMessages = <Map<String, dynamic>>[].obs;
var isShortMessagesLoading = false.obs;
var shortMessagesError = ''.obs;
var shortMessagesTotalPages = 1.obs; // ✅ ADD
var shortMessagesCurrentPage = 1.obs; // ✅ ADD

Future<void> fetchShortMessages({int page = 1, int paginate = 10}) async {
  try {
    isShortMessagesLoading.value = true;
    shortMessagesError.value = '';

    final parentUserId  = await userData.getParentUserId();
    final currentUserId = await userData.getLoggedInUserId();
    final apiKey        = await userData.getApiKey();
    final userPrivilage = await userData.getUserPrivilage();
    final currentUserRole = await userData.getUserRole();

    Map<String, dynamic> jsonData = {
      "parent_user_id":    parentUserId,
      "current_user_id":   currentUserId.toString(),
      "api_key":           apiKey,
      "current_user_role": currentUserRole,
      "user_privilage":    userPrivilage,
      "status":            "active",
      "paginate":          paginate,  // number per page (configurable)
      "page":              page,      // ✅ page number
    };

    Map<String, String> headers = {
      "X-Client-GetGabs": apiKey.toString(),
      "Content-Type": "application/json",
    };

    final response = await chatServices.shortMessageListService(
      jsonData, headers: headers);

    debugPrint('Short messages response: $response');

    if (response['status'] == true) {
      final msgData = response['message'];
      final List raw = msgData['data'] ?? [];

      // ✅ Pagination info
      shortMessagesCurrentPage.value = msgData['current_page'] ?? 1;
      final lastPage = msgData['last_page'] ?? 
                       msgData['total_pages'] ?? 
                       1;
      shortMessagesTotalPages.value = lastPage;

      shortMessages.value =
          raw.map((e) => Map<String, dynamic>.from(e)).toList();
    } else {
      shortMessagesError.value =
          response['message']?.toString() ?? 'Failed to load';
    }
  } catch (e) {
    debugPrint('❌ fetchShortMessages error: $e');
    shortMessagesError.value = 'Something went wrong';
  } finally {
    isShortMessagesLoading.value = false;
  }
} 
  void handleIncomingMessage(dynamic data) {
    debugPrint('Chat data mc: $data');
    
    var messageData = data['data'];
    if (messageData != null) {
      if (messageData['profile_wa_key'] == profileWaKey) {
        debugPrint('📱 New message received from: ${messageData['profile_wa_key']}');
        var receivedMessage = Message.fromJson(messageData);

        // The backend re-sends the SAME message over FCM as its
        // delivery_status progresses (sent → delivered → read), not just
        // for genuinely new messages — this same messageId is what
        // keyForMessage() caches one GlobalKey for, so blindly re-inserting
        // it as a second row would hand two widgets the same GlobalKey
        // ("Multiple widgets used the same GlobalKey", thrown repeatedly).
        // So: if it's already in the list, this is a status update — apply
        // it in place instead of ignoring it, which is what made read/
        // delivered ticks depend entirely on the slower 3-second REST
        // resync fallback instead of updating instantly off this push.
        final existingIndex = messageChatList
            .indexWhere((m) => m.messageId == receivedMessage.messageId);
        if (existingIndex != -1) {
          final current = messageChatList[existingIndex];
          if (current.deliveryStatus?.toLowerCase() !=
              receivedMessage.deliveryStatus?.toLowerCase()) {
            messageChatList[existingIndex] = current.copyWith(
              deliveryStatus: receivedMessage.deliveryStatus,
            );
            groupedMessages.assignAll(groupMessagesByDate(messageChatList));
            debugPrint('✅ Status updated live for '
                '${receivedMessage.messageId}: ${receivedMessage.deliveryStatus}');
          }
          return;
        }

        // Insert the new message at the beginning of the list
        messageChatList.insert(0, receivedMessage);
        groupedMessages.assignAll(groupMessagesByDate(messageChatList));

        // markChatAsRead is a local list update (no network call) — the
        // dashboard row's unread badge was already bumped by
        // bumpChatOnIncomingMessage() before this ran, so this only needs
        // to zero it back out since this chat is open. A REST-refetch
        // refreshActiveChatList() call used to sit here too, re-fetching
        // and replacing the *entire* dashboard chat list on every single
        // incoming message while this chat was open — same "poori list
        // update ho rahi hai" issue fixed elsewhere, just a second spot it
        // was still happening from.
        if (Get.isRegistered<DashboardController>()) {
          Get.find<DashboardController>().markChatAsRead(profileWaKey);
        }

        // Mark message as read IMMEDIATELY using cached user info
        debugPrint('⚡ INSTANT read status - Message ID: ${receivedMessage.messageId}');
        debugPrint('📤 Sending read with - role: $role, userId: $userId, adminId: $adminId (type: ${adminId.runtimeType})');
        
        // Check if adminId is initialized properly
        if (adminId.contains('Future') || adminId.isEmpty) {
          debugPrint('⚠️ WARNING: adminId not initialized properly! Value: $adminId');
          return; // Skip emit if adminId is not ready
        }
        
        _socketsController?.updateChatToRead(
            role: role,
            userId: userId,
            adminId: adminId,
            messageId: receivedMessage.messageId,
            profileWaKey: profileWaKey);
      }
    }
  }

  /// Inserts a locally-known "note" message (returned synchronously by the
  /// Assign/Co-Assign/Team-Assign APIs) at the top of the chat so the user
  /// sees the assignment note immediately, without waiting for it to arrive
  /// over the socket. Skips the insert if a message with the same id is
  /// already present, in case the backend also pushes the same note over
  /// the socket (handleIncomingMessage would otherwise insert it a second time).
  void insertNoteMessage(Message noteMessage) {
    final alreadyPresent = messageChatList
        .any((m) => m.messageId == noteMessage.messageId);
    if (alreadyPresent) return;
    messageChatList.insert(0, noteMessage);
    groupedMessages.assignAll(groupMessagesByDate(messageChatList));
  }

  /// Mark a single message as read immediately
  Future<void> markMessageAsReadImmediately(String messageId) async {
    try {
      debugPrint('⚡ Marking message $messageId as read IMMEDIATELY');
      _socketsController?.updateChatToRead(
        role: role,
        userId: userId,
        adminId: adminId,
        messageId: messageId,
        profileWaKey: profileWaKey,
      );
    } catch (e) {
      debugPrint('❌ Error marking message as read: $e');
    }
  }

  // Buffers status events that arrive for a message before its temp ID has
  // been swapped for the server-assigned ID (see updateMessageId below).
  final Map<String, dynamic> _pendingStatusUpdates = {};

  void handelIcomingMessageStatus(dynamic data) {
    debugPrint('Chat status: $data');

    // Normalize to String: the socket payload's message_id can arrive as a
    // number while Message.messageId is always a String, which made the
    // indexWhere below fail to match and silently drop every status update.
    var messageId = data['data']['message_id']?.toString();
    var deliveryStatus = data['data']['delivery_status'];
    debugPrint("((((((((((((((((((()))))))))))))))))))");
    debugPrint('📨 Raw delivery status: "$deliveryStatus" (type: ${deliveryStatus.runtimeType})');

    int index = messageChatList.indexWhere((msg) => msg.messageId == messageId);

    if (index != -1) {
      if (data['data']['message_type'] == "template") {
        // Keep the subuser id we already know locally — the server's
        // status payload doesn't always carry it (e.g. the admin's own
        // sends), which broke "You"/sender-name attribution otherwise.
        final existingSubuserSenderId = messageChatList[index].subuserSenderId;
        messageChatList[index] = Message.fromJson(data['data'])
            .copyWith(subuserSenderId: existingSubuserSenderId);
      } else {
        // Normalize the status to lowercase for consistency
        final normalizedStatus = deliveryStatus?.toString().toLowerCase() ?? 'sent';
        debugPrint('✅ Updating message $messageId status to: $normalizedStatus');
        messageChatList[index] =
            messageChatList[index].copyWith(deliveryStatus: normalizedStatus);
      }

      groupedMessages.assignAll(groupMessagesByDate(messageChatList));
    } else {
      // The status event beat updateMessageId() here — the message is still
      // in the list under its temporary ID. Buffer it so it can be applied
      // as soon as the real ID is assigned instead of being silently dropped.
      debugPrint('⏳ No match for $messageId yet, buffering status update');
      if (messageId != null) {
        _pendingStatusUpdates[messageId] = data['data'];
      }
    }
  }

  // Shows the WhatsApp-style "jump to latest" button once the user has
  // scrolled away from the newest message — in this reverse:true list that
  // means AWAY from pixel offset 0, not maxScrollExtent (which is the
  // OLDEST end, already used above for pagination).
  var showJumpToLatest = false.obs;

  void _scrollListener() {
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - 50) {
      if (!isApiCallInProgress) {
        loadMoreMessages(profileWaKey);
      }
    }

    final shouldShowJump = scrollController.position.pixels > 200;
    if (shouldShowJump != showJumpToLatest.value) {
      showJumpToLatest.value = shouldShowJump;
    }
  }

  Future<void> jumpToLatestMessage() async {
    if (!scrollController.hasClients) return;
    await scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  void disposeScrollListner() {
    scrollController.removeListener(_scrollListener);
    scrollController.dispose();
  }

  bool isApiCallInProgress = false;
  Future<void> loadChatsApi({required var userKey, var from = 'inside'}) async {
    try {
      final parentUserId = await userData.getParentUserId();
      final currentUserId = await userData.getLoggedInUserId();
      final apiKey = await userData.getApiKey();
      final customerKey = userKey;
      final currentUserRole = await userData.getUserRole();
      final userPrivilage = await userData.getUserPrivilage();
       debugPrint('Loading chats - page: $parentUserId, userKey: $currentUserId, from: $apiKey, customerKey: $customerKey, currentUserRole: $currentUserRole, userPrivilage: $userPrivilage');

      Map data = {
        "parent_user_id": parentUserId,
        "current_user_id": currentUserId,
        "api_key": apiKey,
        "customer_key": customerKey,
        "current_user_role": currentUserRole,
        "page": currentPage.toString(),
        "user_privilage": userPrivilage
      };
      Map<String, String> headers = {
        "X-Client-GetGabs": apiKey.toString(),
        "Content-Type": "application/json"
      };

      // configLoading();
      // showLoading();
      if (isApiCallInProgress) return;
      isApiCallInProgress = true;
      chatServices.loadChats(data, headers: headers).then((value) {
        if (value['status']) {
          // EasyLoading.dismiss();
          List<dynamic> chatsList = value['message']['data']['data'] ?? [];
          // messageChatList.assignAll(
          // chatsList.map((datas) => Message.fromJson(datas)).toList());

          if (from == 'inside') {
            messageChatList.addAll(
                chatsList.map((datas) => Message.fromJson(datas)).toList());
          } else {
            messageChatList.assignAll(
                chatsList.map((datas) => Message.fromJson(datas)).toList());
          }
          // An empty page means we've reached the start of the
          // conversation — nothing older left to fetch for a quoted-message
          // lookup, so stop trying instead of endlessly repaging.
          hasMoreMessages = chatsList.isNotEmpty;
          currentPage++;
        } else {
          // print('2342342342343klkljlkjlkjlkjlkjlkjlkjl');
          // EasyLoading.dismiss();
        }
      }).onError((error, stackTrace) {
        debugPrint(error.toString());
        debugPrint(stackTrace.toString());
      }).whenComplete(() {
        isApiCallInProgress = false;
        if (from == 'outside') isInitialChatLoading.value = false;
        // Mark all received messages as read after loading
        markAllReceivedMessagesAsRead();
      });
    } catch (error, stackTrace) {
      debugPrint('Error: $error');
      debugPrint('Stack Trace: $stackTrace');
      if (from == 'outside') isInitialChatLoading.value = false;
      // EasyLoading.dismiss();
    }
  }

  /// Mark all received messages as read and notify the sender immediately
  Future<void> markAllReceivedMessagesAsRead() async {
    try {
      debugPrint('📖 Marking all received messages as read');
      debugPrint('🔍 User info check - role: $role (type: ${role.runtimeType}), userId: $userId (type: ${userId.runtimeType}), adminId: $adminId (type: ${adminId.runtimeType})');
      
      // Check if user info is properly initialized
      if (adminId.contains('Future') || adminId.isEmpty) {
        debugPrint('⚠️ WARNING: User info not initialized! Skipping read-status emission.');
        return;
      }
      
      List<String> messagesToMarkAsRead = [];

      // Detailed debug: show why messages may be skipped
      for (var message in messageChatList) {
        final msgId = message.messageId;
        final isSent = message.isSentByMe;
        final delStatus = message.deliveryStatus?.toString() ?? 'null';
        final markReadFlag = message.markMsgAsRead;
        final seenByUser = message.seenByUser;
        final seenByAdmin = message.seenByAdmin;
        debugPrint('🔎 Message: $msgId | senderIsMe: $isSent | deliveryStatus: $delStatus | markMsgAsRead: $markReadFlag | seenByUser: $seenByUser | seenByAdmin: $seenByAdmin');

        // Only mark messages that are NOT sent by you and not already read
        if (!isSent && delStatus.toLowerCase() != 'read') {
          messagesToMarkAsRead.add(msgId);
        }
      }

      // If none found, attempt a sensible fallback: mark the latest received message
      if (messagesToMarkAsRead.isEmpty) {
        Message? lastReceived;
        for (var m in messageChatList) {
          if (!m.isSentByMe) {
            lastReceived = m;
            break;
          }
        }
        if (lastReceived != null) {
          debugPrint('⚠️ No unread messages candidates found — falling back to latest received: ${lastReceived.messageId}');
          messagesToMarkAsRead.add(lastReceived.messageId);
        }
      }

      // Send read status for each message immediately (no delays)
      for (var messageId in messagesToMarkAsRead) {
        debugPrint('⚡ Sending read status NOW for message: $messageId');
        _socketsController?.updateChatToRead(
          role: role,
          userId: userId,
          adminId: adminId,
          messageId: messageId,
          profileWaKey: profileWaKey,
        );
      }
    messageChatList.refresh();
      groupedMessages.assignAll(groupMessagesByDate(messageChatList));
      
      debugPrint('✅ All messages marked as read - ${messagesToMarkAsRead.length} emitted');
    } catch (e) {
      debugPrint('❌ Error marking messages as read: $e');
    }
  }

  void loadMoreMessages(String profileWaKey) {
    loadChatsApi(
        userKey:
            profileWaKey); // Replace 'your_user_key' with the actual user key
  }

  // A reply's quoted-message lookup (see buildMessageWidget's 'reply_msg'
  // branch) only searches messages already loaded into messageChatList —
  // on a fresh chat open that's just the first page. Notes/early templates
  // tend to be OLDER (created near the start of the conversation), so they
  // miss that first page far more often than a recent text reply does,
  // which is why "text works, template/note doesn't until I scroll up"
  // happens: scrolling up is exactly what triggers loading those older
  // pages. This auto-loads a few more pages in the background — bounded,
  // so a genuinely missing/deleted message doesn't loop forever — instead
  // of requiring the user to manually scroll to reveal the quoted box.
  final Set<String> _autoLoadingQuotedFor = {};
  final Set<String> _autoLoadExhaustedFor = {};

  void ensureMessageLoaded(String messageId, {bool forceRetry = false}) {
    if (_autoLoadingQuotedFor.contains(messageId)) return;
    if (messageChatList.any((m) => m.messageId == messageId)) return;
    if (forceRetry) {
      // A manual retry tap should always get a fresh attempt — even if a
      // previous automatic search gave up, or the conversation looked
      // fully paged-through at the time.
      _autoLoadExhaustedFor.remove(messageId);
      hasMoreMessages = true;
    } else if (_autoLoadExhaustedFor.contains(messageId)) {
      return;
    }
    _autoLoadingQuotedFor.add(messageId);
    _autoLoadUntilFound(messageId);
  }

  Future<void> _autoLoadUntilFound(String messageId) async {
    // No fixed page cap — a quoted message replied to from way back in a
    // long conversation should still resolve automatically. The real stop
    // condition is reaching the actual start of the conversation
    // (hasMoreMessages turns false); this ceiling only guards against a
    // runaway loop if that never happens (e.g. a deleted message).
    const maxExtraPages = 200;
    try {
      for (var i = 0; i < maxExtraPages; i++) {
        if (messageChatList.any((m) => m.messageId == messageId)) return;
        if (!hasMoreMessages) break;
        // Don't fight the regular pagination/status-resync calls already
        // in flight — wait a beat and check again instead of racing them.
        var waited = 0;
        while (isApiCallInProgress && waited < 2000) {
          await Future.delayed(const Duration(milliseconds: 200));
          waited += 200;
        }
        await loadChatsApi(userKey: profileWaKey);
        if (messageChatList.any((m) => m.messageId == messageId)) return;
      }
      _autoLoadExhaustedFor.add(messageId);
      // Nothing about groupedMessages itself changed, but the reply's
      // quoted-box needs to re-check isQuotedMessageUnavailable now that
      // the search has given up, so it can show an error instead of
      // staying blank forever.
      groupedMessages.refresh();
    } finally {
      _autoLoadingQuotedFor.remove(messageId);
    }
  }

  // True once ensureMessageLoaded has searched maxExtraPages worth of
  // history for this id and still come up empty — the quoted-preview box
  // uses this to show "Original message not found" instead of staying
  // blank forever while (from the user's point of view) nothing seems to
  // be happening.
  bool isQuotedMessageUnavailable(String messageId) =>
      _autoLoadExhaustedFor.contains(messageId);

  /// Timestamp basis for our own optimistic (sent) messages that MATCHES how
  /// received messages are stored — [Message.fromJson] shifts the server's UTC
  /// `created_at` by +5:30. Keeping sent and received on the SAME basis makes
  /// `createdAt` a correct, consistent sort key, so a burst of messages
  /// sent/received together renders in the right sequence instead of depending
  /// on the (arbitrary) order socket events arrived in. The bubbles read
  /// `.hour`/`.minute` (wall clock), so the displayed time is unchanged.
  DateTime _messageTimestampNow() =>
      DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

  /// Authoritative ordering for two messages.
  ///
  /// The server's monotonic `id` is the single source of truth for sequence —
  /// it reflects true creation order and is immune to the whole-second rounding
  /// of incoming WhatsApp timestamps and to device-vs-server clock skew (which
  /// is exactly what made a late-delivered incoming message land *after* an
  /// outgoing one during rapid back-and-forth). A message we just sent has no
  /// server id yet (`id == 0`); it is by definition the newest thing in the
  /// chat, so it sorts last until the server confirms it and its real id
  /// arrives (via [updateMessageId] or the status resync).
  int _messageOrder(Message a, Message b) {
    // PRIMARY: true send time.
    //
    // A received message carries the WhatsApp timestamp — the customer's real
    // send time — and our own sent messages use the same +5:30 basis (see
    // _messageTimestampNow). So createdAt reflects when each message was
    // actually sent, NOT when it happened to reach us. This is what makes a
    // late-delivered incoming message slot into its correct earlier position
    // instead of dropping to the bottom below messages we sent afterwards.
    //
    // (The server's monotonic `id` is deliberately NOT the primary key: it is
    // assigned when the message is inserted server-side, so a message delayed
    // in the WhatsApp→webhook pipeline gets a *later* id than its true send
    // order — which reordered the chat wrongly.)
    final byTime = a.createdAt.compareTo(b.createdAt);
    if (byTime != 0) return byTime;
    // Same second (incoming timestamps are whole-second) → break the tie
    // deterministically with the server id, then the message id.
    if (a.id > 0 && b.id > 0 && a.id != b.id) return a.id.compareTo(b.id);
    return a.messageId.compareTo(b.messageId);
  }

  // WhatsApp reactions arrive as their own message with message_type ==
  // 'reaction' — the payload references the ORIGINAL message via
  // reaction.message_id, not a message of its own. Strips those entries out
  // of the displayed list and returns {targetMessageId: emoji} so the caller
  // can attach the emoji to that message instead of showing raw reaction
  // JSON as a separate bubble. An empty emoji means the reaction was removed.
  Map<String, String> _extractReactions(List<Message> messages) {
    final reactionEntries =
        messages.where((m) => m.messageType == 'reaction').toList()
          ..sort(_messageOrder);
    final Map<String, String> reactionByTargetId = {};
    for (final r in reactionEntries) {
      try {
        final decoded = jsonDecode(r.messageText);
        final targetId = decoded['reaction']?['message_id']?.toString();
        final emoji = decoded['reaction']?['emoji']?.toString() ?? '';
        if (targetId == null || targetId.isEmpty) continue;
        if (emoji.isEmpty) {
          reactionByTargetId.remove(targetId);
        } else {
          reactionByTargetId[targetId] = emoji;
        }
      } catch (_) {}
    }
    return reactionByTargetId;
  }

  Map<String, List<Message>> groupMessagesByDate(List<Message> messages) {
    final reactionByTargetId = _extractReactions(messages);
    final displayable = messages
        .where((m) => m.messageType != 'reaction')
        .map((m) {
          final emoji = reactionByTargetId[m.messageId];
          return emoji != null ? m.copyWith(reactionEmoji: emoji) : m;
        })
        .toList();

    // Order by the authoritative sequence (see _messageOrder) so the displayed
    // order never depends on the order socket events happened to arrive in — a
    // rapid burst of incoming/outgoing messages used to render out of sequence
    // because each was blindly inserted at index 0.
    final sorted = List<Message>.from(displayable)..sort(_messageOrder);

    // Build each day's bucket oldest-first (top → bottom within the day).
    final Map<String, List<Message>> grouped = {};
    for (final message in sorted) {
      final date = message.createdAt.toString().split(' ')[0];
      (grouped[date] ??= <Message>[]).add(message);
    }

    // Emit date keys newest-day-first so the reverse:true ListView puts the
    // most recent day at the bottom of the screen (WhatsApp layout).
    final orderedKeys = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    return {for (final key in orderedKeys) key: grouped[key]!};
  }

  RxMap<String, List<Message>> groupedMessages = <String, List<Message>>{}.obs;

  // Drives the initial-load skeleton in MessagesPage — true until the very
  // first ("outside") loadChatsApi call finishes, success or failure. Kept
  // separate from isApiCallInProgress so pagination loads (from: 'inside')
  // never re-trigger the skeleton.
  var isInitialChatLoading = true.obs;

  var textEditingController = TextEditingController();

  // Swipe-to-reply state — set when the user swipes a message to reply to
  // it (see SwipeToReplyWrapper), read by sendMessage() to decide whether
  // to send a normal text message or a reply via sendReplyApi, and by the
  // composer's "Replying to" preview bar.
  Rx<Message?> replyingToMessage = Rx<Message?>(null);
  final FocusNode textFieldFocusNode = FocusNode();

  void startReply(Message message) {
    replyingToMessage.value = message;
    textFieldFocusNode.requestFocus();
  }

  void cancelReply() {
    replyingToMessage.value = null;
  }

  void sendMessage(String customerKey) {
    if (textEditingController.text.trim().isEmpty) {
      return;
    }

    final repliedMessage = replyingToMessage.value;
    String tempMessageId =
        DateTime.now().millisecondsSinceEpoch.toString(); // Temporary ID

    // A reply's messageText mirrors the sendReplyChat response shape
    // ({"msgcontent": ..., "message_id": <quoted message's id>}) so the
    // existing 'reply_msg' rendering path (see buildMessageWidget) picks it
    // up the same way a reload from the server would.
    final messageText = repliedMessage != null
        ? jsonEncode({
            'msgcontent': textEditingController.text,
            'message_id': repliedMessage.messageId,
          })
        : textEditingController.text;

    // Snapshot of the ORIGINAL message being replied to, in the shape
    // ReplyMessageUi.buildReplyMessageWidget already expects — this is what
    // draws the little quoted-message box above the reply text (WhatsApp-
    // style). Without it the reply still sends fine, it just shows no
    // quoted preview.
    final replyFormSnapshot = repliedMessage != null
        ? jsonEncode({
            'message_id': repliedMessage.messageId,
            'message_type': repliedMessage.messageType,
            'message_text': repliedMessage.messageText,
            'template_data': repliedMessage.templateData,
            'local': repliedMessage.local,
            'quoted_sender_name': resolveQuotedSenderName(repliedMessage),
          })
        : '';

    var newMessage = Message(
        id: 0, // 0 = optimistic (not yet server-confirmed); real id set on ack
        messageText: messageText,
        messageId: tempMessageId,
        messageType: repliedMessage != null ? "reply_msg" : "text",
        isAutoreply: false,
        sender: 0,
        seenByAdmin: false,
        markMsgAsRead: false,
        seenByUser: false,
        deliveryStatus: "sending", // Temporary status
        createdAt: _messageTimestampNow(),
        updatedAt: _messageTimestampNow(),
        replyformsg: replyFormSnapshot,
        // Composed on THIS device by whoever is logged in right now — no
        // need to wait for the server's subuser_sender_id to know who sent
        // it, so the "You"/teammate-name attribution works immediately.
        subuserSenderId: userId);

    messageChatList.insert(0, newMessage);
    groupedMessages.assignAll(groupMessagesByDate(messageChatList));

    if (Get.isRegistered<DashboardController>()) {
      Get.find<DashboardController>().bumpChatOnNewActivity(profileWaKey);
    }

    // Sending should always land you on what you just sent — if the user
    // had scrolled up to older messages, the new one (inserted at the
    // reverse:true list's position 0) would otherwise go unseen off the
    // bottom of the screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      jumpToLatestMessage();
    });

    if (repliedMessage != null) {
      sendReplyApi(customerKey, tempMessageId, repliedMessage.messageId);
      cancelReply();
    } else {
      sendMessageApi(customerKey, tempMessageId);
    }
  }

  void downloadMedia(Message message) async {
    final url =
        "https://app.getgabs.com/customers/mediafile/${message.messageText}";
    final filename = url.split('/').last;
    final Directory directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/$filename';

    try {
      final response = await Dio().download(url, filePath);
      if (response.statusCode == 200) {
        // Update the message with the local path and set local to true
        final updatedMessage = message.copyWith(
          messageText: filePath,
          local: true,
        );
        // Replace the old message with the new one in the list
        int index = messageChatList.indexWhere((msg) => msg.id == message.id);
        if (index != -1) {
          messageChatList[index] = updatedMessage;
          groupedMessages.assignAll(groupMessagesByDate(messageChatList));
        }
      }
    } catch (e) {
      debugPrint('Download error: $e');
    }
  }

  void sendMediaMessage(String customerKey, String media, String mediaType,
      String caption, bool isVideo, bool isDocument) {
    String tempMessageId =
        DateTime.now().millisecondsSinceEpoch.toString(); // Temporary ID

    var newMessage = Message(
        id: 0, // 0 = optimistic (not yet server-confirmed); real id set on ack
        messageText: media, // No text for media message
        messageId: tempMessageId, // Generate a unique messageId
        messageType: mediaType, // Message type: image or video
        isAutoreply: false,
        sender: 0, // Assuming the sender is the user
        seenByAdmin: false,
        markMsgAsRead: false,
        seenByUser: false,
        createdAt: _messageTimestampNow(),
        updatedAt: _messageTimestampNow(),
        local: true,
        deliveryStatus: "sending",
        replyformsg: '',
        captionText: caption, // ✅ ✅ ✅ MOST IMPORTANT LINE
        // Temporarily set file path, replace with URL after upload
        subuserSenderId: userId);

    messageChatList.insert(0, newMessage); // Insert at the beginning

    groupedMessages.assignAll(groupMessagesByDate(messageChatList));

    if (Get.isRegistered<DashboardController>()) {
      Get.find<DashboardController>().bumpChatOnNewActivity(profileWaKey);
    }

    sendMessageWithMedia(
        media, caption, isVideo, customerKey, tempMessageId, isDocument);
  }

  Future<void> sendMessageApi(String customerKey, String tempMessageId) async {
    final parentUserId = await userData.getParentUserId();
    final currentUserId = await userData.getLoggedInUserId();
    final apiKey = await userData.getApiKey();
    // final customerKey = customerKey;
    final currentUserRole = await userData.getUserRole();
    final userPrivilage = await userData.getUserPrivilage();

    String messageText = textEditingController.value.text.trim();

    Map<String, dynamic> jsonData = {
      "parent_user_id": parentUserId,
      "current_user_id": currentUserId.toString(),
      "api_key": apiKey,
      "customer_key": customerKey,
      "type": "text",
      "text": messageText,
      "current_user_role": currentUserRole,
      "user_privilage": userPrivilage
    };
    Map<String, dynamic> data = {"jsondata": jsonData};
    textEditingController.clear();

    Map<String, String> headers = {
      "X-Client-GetGabs": apiKey.toString(),
      "Content-Type": "application/json"
    };

    chatServices.sendMessageService(data, headers: headers).then((value) {
      if (value['status']) {
        print(value);
        var actualMessageId = value['message']['message_id'].toString();
        // Capture the server's numeric id if the response carries one, so this
        // message joins the id-ordered sequence in its correct position. If it
        // doesn't, the status resync backfills it from the server shortly.
        final serverId =
            int.tryParse(value['message']['id']?.toString() ?? '');
        final serverCreatedAt = value['message']['created_at']?.toString();
        updateMessageId(tempMessageId, actualMessageId,
            serverId: serverId, serverCreatedAt: serverCreatedAt);
      } else {
        print(value);
      }
    }).onError((error, stackTrace) {});
  }

  /// Sends a reply-to-a-specific-message via sendReplyChat instead of the
  /// normal text-send endpoint. Mirrors sendMessageApi's shape (same
  /// jsondata wrapper, same optimistic-message id swap on success) — see
  /// the sendReplyChat API doc for the exact admin/sub-user payload.
  Future<void> sendReplyApi(String customerKey, String tempMessageId,
      String repliedMessageId) async {
    final parentUserId = await userData.getParentUserId();
    final currentUserId = await userData.getLoggedInUserId();
    final apiKey = await userData.getApiKey();
    final currentUserRole = await userData.getUserRole();
    final userPrivilage = await userData.getUserPrivilage();

    final msgContent = textEditingController.value.text.trim();

    Map<String, dynamic> jsonData = {
      "parent_user_id": parentUserId,
      "current_user_id": currentUserId.toString(),
      "api_key": apiKey,
      "customer_key": customerKey,
      "msgcontent": msgContent,
      "message_id": repliedMessageId,
      "current_user_role": currentUserRole,
      "user_privilage": userPrivilage,
    };
    Map<String, dynamic> data = {"jsondata": jsonData};
    textEditingController.clear();

    Map<String, String> headers = {
      "X-Client-GetGabs": apiKey.toString(),
      "Content-Type": "application/json",
    };

    chatServices.sendReplyChatService(data, headers: headers).then((value) {
      if (value['status'] == true) {
        final actualMessageId =
            value['message']['message_id']?.toString() ?? tempMessageId;
        final serverId =
            int.tryParse(value['message']['id']?.toString() ?? '');
        updateMessageId(tempMessageId, actualMessageId, serverId: serverId);
      } else {
        debugPrint('❌ sendReplyApi failed: $value');
      }
    }).onError((error, stackTrace) {
      debugPrint('❌ sendReplyApi error: $error');
    });
  }

  /// Parses a server timestamp string onto the SAME basis as received
  /// messages (see [Message.fromJson], which shifts UTC by +5:30), so all
  /// messages share one time basis and sort consistently.
  DateTime? _parseServerTimestamp(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return DateTime.parse(raw).add(const Duration(hours: 5, minutes: 30));
    } catch (_) {
      return null;
    }
  }

  void updateMessageId(String tempMessageId, String actualMessageId,
      {int? serverId, String? serverCreatedAt}) {
    int index =
        messageChatList.indexWhere((msg) => msg.messageId == tempMessageId);
    print(index);
    print('helllloworldddddd');
    if (index != -1) {
      // The API confirmed the message reached the server, so it's at least
      // "sent" now — swap the temp ID and clear the "sending" clock icon.
      // Also adopt the server's created_at so our optimistic (device-clock)
      // timestamp is replaced by the authoritative one — this makes the LIVE
      // order match what a reopen (server-loaded) shows, even if the device
      // clock drifts from the server.
      messageChatList[index] = messageChatList[index].copyWith(
          messageId: actualMessageId,
          deliveryStatus: 'sent',
          id: (serverId != null && serverId > 0) ? serverId : null,
          createdAt: _parseServerTimestamp(serverCreatedAt));
      print(messageChatList[index].messageText);
      print(actualMessageId);
      print('datatemplateeeee');
      print(messageChatList[index].templateData);

      // Apply any status update (delivered/read) that arrived via socket
      // before we got here and was buffered under the real message ID.
      final pending = _pendingStatusUpdates.remove(actualMessageId);
      if (pending != null) {
        if (pending['message_type'] == "template") {
          final existingSubuserSenderId =
              messageChatList[index].subuserSenderId;
          messageChatList[index] = Message.fromJson(pending)
              .copyWith(subuserSenderId: existingSubuserSenderId);
        } else {
          final normalizedStatus =
              pending['delivery_status']?.toString().toLowerCase() ?? 'sent';
          messageChatList[index] =
              messageChatList[index].copyWith(deliveryStatus: normalizedStatus);
        }
      }

      groupedMessages.assignAll(groupMessagesByDate(messageChatList));
    }
  }

  Future<void> sendMessageWithMedia(String filePath, String caption,
      bool isVideo, String key, String tempMessageId, bool isDocument) async {
    final parentUserId = await userData.getParentUserId();
    final currentUserId = await userData.getLoggedInUserId();
    final apiKey = await userData.getApiKey();
    final currentUserRole = await userData.getUserRole();
    final customerKey = key; // Replace with the actual customer key
    final userPrivilage = await userData.getUserPrivilage();

    // String type = isVideo ? 'video' : 'image';
    String type;
    if (isDocument) {
      type = 'document';
    } else {
      type = (isVideo ? 'video' : 'image');
    }
    // Create the JSON data
    Map<String, dynamic> jsonData = {
      "parent_user_id": parentUserId,
      "current_user_id": currentUserId.toString(),
      "api_key": apiKey,
      "customer_key": customerKey,
      "type": type,
      "caption": caption,
      "current_user_role": currentUserRole,
      "user_privilage": userPrivilage
    };

    // Create a multipart request
    var request = http.MultipartRequest(
        'POST',
        Uri.parse(
            'https://app.getgabs.com/v2/flutterapplication/sendmessages'));

    // Add the JSON data as a field
    request.fields['jsondata'] = json.encode(jsonData);

    // Add the file
    request.files.add(await http.MultipartFile.fromPath('file', filePath));

    // Set headers
    request.headers.addAll({
      "X-Client-GetGabs": apiKey.toString(),
      "Content-Type": "multipart/form-data"
    });

    try {
      // Send the request
      var response = await request.send();

      // Get the response body
      final responseBody = await response.stream.bytesToString();
      final parsedResponse = json.decode(responseBody);

      // Print the response body
      print('Response Body: $responseBody');
      // Handle the response
      if (response.statusCode == 200) {
        print('Message sent successfully');
        final message = parsedResponse['message'];

        final messageText = message['message_text'];
        final messageType = message['message_type'];
        // sendMediaMessage(key, messageText, messageType);
        var actualMessageId = message['message_id'].toString();
        final serverId = int.tryParse(message['id']?.toString() ?? '');
        final serverCreatedAt = message['created_at']?.toString();
        updateMessageId(tempMessageId, actualMessageId,
            serverId: serverId,
            serverCreatedAt: serverCreatedAt); // sync id + server time
      } else {
        print('Failed to send message');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  void sendHelloWorldMessageTemplate(
      String customerKey, String messageText, String template) {
    String tempMessageId =
        DateTime.now().millisecondsSinceEpoch.toString(); // Temporary ID

    var newMessage = Message(
        id: 0, // 0 = optimistic (not yet server-confirmed); real id set on ack
        messageText: messageText,
        messageId: tempMessageId,
        messageType: "template",
        isAutoreply: false,
        sender: 0,
        seenByAdmin: false,
        markMsgAsRead: false,
        seenByUser: false,
        templateData: template,
        deliveryStatus: "sending", // Temporary status
        createdAt: _messageTimestampNow(),
        updatedAt: _messageTimestampNow(),
        replyformsg: '',
        subuserSenderId: userId);

    messageChatList.insert(0, newMessage);
    groupedMessages.assignAll(groupMessagesByDate(messageChatList));
    //sendHelloWorldTemplateApi(customerKey, tempMessageId);
  }

  void updateTemplateMessageId(
      String tempMessageId, String actualMessageId, dynamic json) {
    int index =
        messageChatList.indexWhere((msg) => msg.messageId == tempMessageId);
    print(index);
    print('helllloworldddddd');

    if (index != -1) {
      // The server's JSON doesn't carry subuser_sender_id for every sender
      // (notably the admin's own sends) — keep the id we already know
      // locally (whoever composed this message on THIS device) instead of
      // losing it to the fresh parse, which broke "You"/sender-name
      // attribution on the message's own live bubble.
      final existingSubuserSenderId = messageChatList[index].subuserSenderId;
      messageChatList[index] = Message.fromJson(json)
          .copyWith(subuserSenderId: existingSubuserSenderId);
      print(messageChatList[index].messageText);
      print(actualMessageId);
      print('datatemplateeeee');
      print(messageChatList[index].templateData);
      groupedMessages.assignAll(groupMessagesByDate(messageChatList));
    }
  }

  Future<void> sendHelloWorldTemplateApi(
      String customerKey, String tempMessageId) async {
    final parentUserId = await userData.getParentUserId();
    final currentUserId = await userData.getLoggedInUserId();
    final apiKey = await userData.getApiKey();
    final userPrivilage = await userData.getUserPrivilage();

    Map<String, dynamic> jsonData = {
      "parent_user_id": parentUserId.toString(),
      "current_user_id": currentUserId.toString(),
      "api_key": apiKey,
      "customer_key": customerKey,
      "user_privilage": userPrivilage
    };
    // Map<String, dynamic> data = {"jsondata": jsonData};
    textEditingController.clear();

    Map<String, String> headers = {
      "X-Client-GetGabs": apiKey.toString(),
      "Content-Type": "application/json"
    };

    chatServices
        .sendHelloWorldTemplateService(jsonData, headers: headers)
        .then((value) {
      if (value['status']) {
        var actualMessageId = value['message']['data']['message_id'].toString();
        updateTemplateMessageId(
            tempMessageId, actualMessageId, value['message']['data']);
      } else {
        print(value);
      }
    }).onError((error, stackTrace) {
      print(error.toString());
      print(stackTrace.toString());
    });
  }

//------------------send-templated-messages-------------------------------------------------
  var availableTemplates = <String>[].obs;
  var currentTemplatePage = 1.obs;
  var isLoadingTemplates = false.obs;
  var canLoadMoreTemplates = true.obs;
  var selectedTamplate = '--Choose Template--'.obs;
  var isOptionSelected = false.obs;

  Future<void> fetchMessageTemplates() async {
        debugPrint('Chat Api Hit 118');
    // if (isLoadingTemplates.value || !canLoadMoreTemplates.value) return;
    if (isLoadingTemplates.value ||
        !canLoadMoreTemplates.value && searchQuery.value.isEmpty) return;

    // Fetching data from user preferences or service
    final parentUserId = await userData.getParentUserId();
    final currentUserId = await userData.getLoggedInUserId();
    final apiKey = await userData.getApiKey();
    final userPrivilage = await userData.getUserPrivilage();
    final roleOfUser = await userData.getUserRole();
    debugPrint('Chat Message parentUserId: $parentUserId, currentUserId: $currentUserId, roleOfUser: $roleOfUser, currentTemplatePage: ${currentTemplatePage.value}, searchQuery: "${searchQuery.value}"');

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

    if (searchQuery.value.trim().isNotEmpty) {
      jsonData['searchTemplate'] = searchQuery.value.trim();
    }

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
          print('Failed to fetch templates: ${response['message']}');
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
          // templateStructure.value = {
          //   'components': components
          // }; // Store only components

          templateStructure.value = {
            'components': components,
            'name': data[0]['name'],
            'language': data[0]['language'],
          };
// // Iterate through the components in templateStructure['components']
//           for (var component in templateStructure['components']) {
//             String type = component['type'];

//             // Check for specific component types and update their boolean value
//             if (type == 'HEADER') {
//               // formatTypes['HEADER'] = true;
//             } else if (type == 'BODY') {
//               // formatTypes['BODY'] = true;
//             } else if (type == 'FOOTER') {
//               // formatTypes['FOOTER'] = true;
//             } else if (type == 'BUTTONS') {
//               // formatTypes['BUTTONS'] = true;
//             } else if (type == 'CAROUSEL') {
//               // formatTypes['CAROUSEL'] = true;
//               isCarousal = true;
//             }
//           }
// print(formatTypes);
          // print('Template Structure: ${data[0]}');
          // print(data[0]['name']['components']);
          // Process and store the template structure here
          // You can create observables to store the template components and update the UI as needed
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

  // List<String> _extractPlaceholders(String urlTemplate) {
  //   RegExp regExp = RegExp(r'\{\{(\d+)\}\}');
  //   return regExp
  //       .allMatches(urlTemplate)
  //       .map((match) => match.group(0) ?? '')
  //       .toList();
  // }

  void resetSelectionTemplate() {
    selectedTamplate.value = '--Choose Template--';
    isTempStrucProgress.value = false;
    templateStructure.clear();
    if (isScreen == 'active') {
      Get.back();
      Get.back();
    } else {
      Get.back();
    }
  }

  void processAndSendTemplate() async {
    print('hello');
    if (templateStructure.isNotEmpty && templateJson.isNotEmpty) {
      final components = templateStructure['components'];
      Map<String, String> variables = {};
      Map<String, String> buttonVariables = {};
      Map<String, String> buttonccVariables = {};
      String selectedPath = '';

      print(components);

      for (var component in components) {
        if (component['type'] == 'HEADER') {
          if (component['format'] == 'IMAGE') {
            isVaribleTemplete.value = true;
            selectedPath = selectedFilePath.value;
          } else if (component['format'] == 'VIDEO') {
            isVaribleTemplete.value = true;
            selectedPath = selectedFilePath.value;
          } else if (component['format'] == 'DOCUMENT') {
            isVaribleTemplete.value = true;
            selectedPath = selectedFilePath.value;
          }
        }

        if (component['type'] == 'BODY') {
          String bodyText = component['text'];
          RegExp regExp = RegExp(r'\{\{(\d+)\}\}');
          Iterable<Match> matches = regExp.allMatches(bodyText);

          for (var match in matches) {
            isVaribleTemplete.value = true;

            int index = int.parse(match.group(1)!);
            index = index - 1;
            // Check if index is within bounds
            if (index < 0 || index >= dynamicTextControllers.length) {
              print(
                  'Index $index is out of bounds for dynamicTextControllers length: ${dynamicTextControllers.length}');
              // continue; // Skip this iteration if the index is invalid
            }
            String userInput = dynamicTextControllers[index].value.text;
            // bodyText = bodyText.replaceFirst('{{${index + 1}}}', userInput);

            print('User input for variable $index: $userInput');
            variables[index.toString()] = userInput; // Store user inputs
          }
        }

        if (component['type'] == 'BUTTONS') {
          List<Map<String, dynamic>> buttonList = [];

          for (var button in component['buttons']) {
            if (button['type'] == 'URL') {
              String buttonUrlTemplate = button['url'];
              RegExp regExp = RegExp(r'\{\{(\d+)\}\}');
              Iterable<Match> matches = regExp.allMatches(buttonUrlTemplate);

              for (var match in matches) {
                isVaribleTemplete.value = true;

                int index = int.parse(match.group(1)!);
                index = index - 1;
                // Check if index is within bounds
                if (index < 0 || index >= dynamicButtonTextControllers.length) {
                  print(
                      'Index $index is out of bounds for dynamicButtonTextControllers length: ${dynamicTextControllers.length}');
                  // continue; // Skip this iteration if the index is invalid
                }
                String userInput =
                    dynamicButtonTextControllers[index].value.text;
                print('User input for variable $index: $userInput');
                buttonVariables[index.toString()] =
                    userInput; // Store user inputs
              }
            }

            if (button['type'] == 'COPY_CODE') {
              for (int i = 0; i < dynamicCopyCodeTextControllers.length; i++) {
                String userInput = dynamicCopyCodeTextControllers[i].value.text;
                print('User input for variable $i: $userInput');
                buttonccVariables[i.toString()] = userInput; //
              }
            }
          }
        }
      }

      final parentUserId = await userData.getParentUserId();
      final currentUserId = await userData.getLoggedInUserId();
      final apiKey = await userData.getApiKey();
      final userPrivilage = await userData.getUserPrivilage();
      final roleOfUser = await userData.getUserRole();

      if (variables.isEmpty &&
          buttonVariables.isEmpty &&
          buttonccVariables.isEmpty &&
          selectedPath.isEmpty) {
        isVaribleTemplete.value = false;
      }

      Map<String, dynamic> jsonData = variables.isEmpty &&
              buttonVariables.isEmpty &&
              buttonccVariables.isEmpty &&
              selectedPath.isEmpty
          ? {
              "parent_user_id": parentUserId,
              "current_user_id": currentUserId,
              "api_key": apiKey,
              "customer_key": profileWaKey,
              // "customer_key": "uhIXPbMpwLmIDKx3a0XpjtjNSS88wDysgNAbxebCxAvXb3sPZn",
              "current_user_role": roleOfUser,
              "user_privilage": userPrivilage,
              "template_data": {
                "to": profileWaId.toString(),
                // "to": "917976554587",
                "type": "template",
                "sender": senderNumber,
                "api_key": apiKey,
                "template": templateJson,
                "campaign_id": "fghgdf", // Replace with actual campaign ID
                "recipient_type": "individual",
                "messaging_product": "whatsapp",
              }
            }
          : createApiRequestFromTemplate(
              variables,
              buttonVariables,
              buttonccVariables,
              selectedPath,
              int.parse(parentUserId),
              currentUserId,
              apiKey,
              userPrivilage,
              roleOfUser,
            );

      var request = http.MultipartRequest(
          'POST',
          Uri.parse(
              'https://app.getgabs.com/v2/flutterapplication/sendtemplatedmsg'));
      print(selectedPath);
      if (selectedPath.isNotEmpty) {
        request.files
            .add(await http.MultipartFile.fromPath('file0', selectedPath));
      }

      // Add the JSON data as a field
      request.fields['jsondata'] = json.encode(jsonData);

      // Add the file

      // Set headers
      request.headers.addAll({
        "X-Client-GetGabs": apiKey.toString(),
        "Content-Type": "multipart/form-data"
      });
      print(request.fields);
      try {
        // Send the request
        var response = await request.send();

        // Get the response body
        final responseBody = await response.stream.bytesToString();
        final parsedResponse = json.decode(responseBody);
        print(response);
        print('000000000000000000000000000000');

        // Print the response body
        print('Response Body: $parsedResponse');
        // Handle the response
        if (response.statusCode == 200) {
          print('Message sent successfully');
          final body = json.decode(responseBody);
          listMessageTemplate(body['message']['data']);
          isTempStrucProgress.value = false;
          resetSelectionTemplate();
          // sendHelloWorldMessageTemplate(
          //     profileWaKey,
          //     body['message']['data']['message_text'],
          //     body['message']['data']['template_data']);
        } else {
          print('Failed to send message');
          // isTempStrucProgress.value = false;
          resetSelectionTemplate();

          ReusableWidgets.snackBar("Error", "Failed to send message");
        }
      } catch (e) {
        print('Error: $e');
        // isTempStrucProgress.value = false;
        resetSelectionTemplate();

        ReusableWidgets.snackBar("Error", "Failed to send message");
      }
    } else {
      print('No template structure or JSON available.');
      resetSelectionTemplate();

      ReusableWidgets.snackBar("Error", "Failed to send message");
      // isTempStrucProgress.value = false;
    }
  }

  void listMessageTemplate(dynamic body
      // int id,String deliveryStatus,
      // String customerKey, String messageText, String template,
      ) {
    //   ;
    // String tempMessageId =
    //     DateTime.now().millisecondsSinceEpoch.toString(); // Temporary ID

    // var newMessage = Message(
    //   id: id,
    //   messageText: messageText,
    //   messageId: tempMessageId,
    //   messageType: "template",
    //   isAutoreply: false,
    //   sender: 0,
    //   seenByAdmin: false,
    //   markMsgAsRead: false,
    //   seenByUser: false,
    //   templateData: template,
    //   deliveryStatus: "sending", // Temporary status
    //   createdAt: DateTime.now(),
    //   updatedAt: DateTime.now(),
    // );

    messageChatList.insert(0, Message.fromJson(body));
    groupedMessages.assignAll(groupMessagesByDate(messageChatList));

    //sendHelloWorldTemplateApi(customerKey, tempMessageId);
  }

  Map<String, dynamic> createApiRequestFromTemplate(
    Map<String, String> userInputs,
    Map<String, String> buttonInputs,
    Map<String, String> buttonccInputs,
    String selectedPath,
    int parentUserId,
    int currentUserId,
    String apiKey,
    int userPrivilage,
    String roleOfUser,
  ) {
    // Create the JSON payload (jsondata object)
    Map<String, dynamic> apiRequest = {
      "parent_user_id": parentUserId,
      "current_user_id": currentUserId,
      "api_key": apiKey,
      "customer_key": profileWaKey,
      // "customer_key": "uhIXPbMpwLmIDKx3a0XpjtjNSS88wDysgNAbxebCxAvXb3sPZn",
      "current_user_role": roleOfUser,
      "user_privilage": userPrivilage,
      "template_data": {
        "to": profileWaId.toString(),
        // "to": "917976554587",
        "type": "template",
        "sender": senderNumber,
        "campaign_id": "gdffd", // Replace with actual campaign ID
        "recipient_type": "individual",
        "messaging_product": "whatsapp",
        "api_key": apiKey,
        "template": {
          "name": templateJson['name'], // Replace with actual template name
          "language": templateJson['language'],
          "components": [] // Initialize components
        },
      }
    };
    // Fetch components from templateJson
    var components = templateJson['components'];

    if (components == null) {
      return {
        "parent_user_id": parentUserId,
        "current_user_id": currentUserId,
        "api_key": apiKey,
        "customer_key": profileWaKey,
        // "customer_key": "uhIXPbMpwLmIDKx3a0XpjtjNSS88wDysgNAbxebCxAvXb3sPZn",
        "current_user_role": roleOfUser,
        "user_privilage": userPrivilage,
        "template_data": {
          "to": profileWaId.toString(),
          // "to": "917976554587",
          "type": "template",
          "sender": senderNumber,
          "campaign_id": "gdffd", // Replace with actual campaign ID
          "recipient_type": "individual",
          "messaging_product": "whatsapp",
          "api_key": apiKey,
          "template": {
            "name": templateJson['name'], // Replace with actual template nameu
            "language": templateJson['language'],
          },
        }
      };
    }

    for (var component in components) {
      print("35345435");

      if (component['type'] == 'HEADER') {
        List<Map<String, dynamic>> parameters = [];

        // Iterate through each parameter in the BODY component
        for (var parameter in component['parameters']) {
          int index = component['parameters'].indexOf(parameter);

          // if (parameter.containsKey('text')) {
          print(selectedPath);

          if (parameter['type'] == 'IMAGE') {
            parameters.add({
              "type": "IMAGE",
              "image": {"link": selectedPath}
            });
          } else if (parameter['type'] == 'VIDEO') {
            parameters.add({
              "type": "VIDEO",
              "video": {"link": selectedPath}
            });
          } else if (parameter['type'] == 'DOCUMENT') {
            parameters.add({
              "type": "DOCUMENT",
              "document": {
                "link": selectedPath,
                "filename": path.basename(selectedPath)
              }
            });
          }

          // }
        }
        apiRequest['template_data']['template']['components'].add({
          "type": "HEADER",
          "parameters": parameters,
        });
      }

      if (component['type'] == 'BODY') {
        List<Map<String, dynamic>> parameters = [];

        // Iterate through each parameter in the BODY component
        for (var parameter in component['parameters']) {
          int index = component['parameters'].indexOf(parameter);

          if (parameter.containsKey('text')) {
            parameters.add({
              "type": "text",
              "text": userInputs[
                  index.toString()] // Use the user input for the placeholder
            });
          }
        }

        // Add the populated BODY component to the API request
        apiRequest['template_data']['template']['components'].add({
          "type": "BODY",
          "parameters": parameters,
        });
      }

      if (component['type'] == 'button') {
        // List<Map<String, dynamic>> buttonList = [];
        List<Map<String, dynamic>> parameters = [];

        // Iterate through each parameter in the BODY component
        for (var parameter in component['parameters']) {
          int index = component['parameters'].indexOf(parameter);

          if (component['sub_type'] == 'COPY_CODE') {
            if (parameter.containsKey('coupon_code')) {
              parameters.add({
                "type": parameter['type'],
                "coupon_code": buttonccInputs[index.toString()]
              });
            }
          }

          if (component['sub_type'] == 'URL') {
            if (parameter.containsKey('text')) {
              parameters.add(
                  {"type": "text", "text": buttonInputs[index.toString()]});
            }
          }
        }

        apiRequest['template_data']['template']['components'].add({
          "type": component['type'],
          "index": component['index'],
          "sub_type": component['sub_type'],
          "parameters": parameters,
        });
      }

      // Handle BUTTONS component similarly if needed (you can extend this)
    }

    return apiRequest; // Return the populated API request JSON
  }

  List<TextEditingController> dynamicTextControllers = [];
  List<TextEditingController> dynamicButtonTextControllers = [];
  List<TextEditingController> dynamicCopyCodeTextControllers = [];

  var validationErrors = <bool>[].obs;
  var validationButtonErrors = <bool>[].obs;
  var validationCopyCodeButtonErrors = <bool>[].obs;
  var isHeaderType = ''.obs;
  void clearPreviousData() {
    for (var controller in dynamicTextControllers) {
      controller.dispose();
    } // Dispose controllers
    dynamicTextControllers.clear();
    if (validationErrors.isNotEmpty) {
      validationErrors.clear();
    }
  }

  // Method to initialize controllers for new templates
  void initializeControllers(List<String> variablePlaceholders) {
    clearPreviousData(); // Clear previous data before initializing new ones

    for (int i = 0; i < variablePlaceholders.length; i++) {
      dynamicTextControllers.add(TextEditingController());
      validationErrors.add(false); // Initialize validation state
    }
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

  // Clear previous data for URL variables
  void clearUrlPreviousData() {
    for (var controller in dynamicButtonTextControllers) {
      controller.dispose();
    }
    dynamicButtonTextControllers.clear();
    if (validationButtonErrors.isNotEmpty) {
      validationButtonErrors.clear();
    }
  }

  // Initialize controllers based on the URL variable placeholders
  void initializeUrlControllers(List<String> variablePlaceholders) {
    clearUrlPreviousData(); // Clear previous data before initializing new ones

    for (int i = 0; i < variablePlaceholders.length; i++) {
      dynamicButtonTextControllers.add(TextEditingController());
      validationButtonErrors.add(false); // Initialize validation state
    }
  }

  // Validate URL input fields
  void validateUrlInputs() {
    for (int i = 0; i < dynamicButtonTextControllers.length; i++) {
      if (dynamicButtonTextControllers[i].text.isEmpty) {
        validationButtonErrors[i] = true; // Set error state if empty
      } else {
        validationButtonErrors[i] = false; // Clear error state
      }
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

  // Initialize controllers based on the URL variable placeholders
  void initializeCopyCodeControllers(int index) {
    clearCopyCodePreviousData();
    index = index - 1;
    print(index);
    print('indexxxxxx');
    dynamicCopyCodeTextControllers.insert(index, TextEditingController());
    validationCopyCodeButtonErrors.insert(index, false);
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

  List<HeaderSelectionController> controllers = [];
//------------------send-templated-messages-------------------------------------------------
// ... inside MessagesPageController class

// ADD THIS: Controller for the search input field
  final TextEditingController searchTemplateController =
      TextEditingController();

// ADD THIS: Reactive variable to hold the live search query
  var searchQuery = ''.obs;

// ADD THIS: New method to reset the list and trigger a search
  void searchTemplates() {
    // Reset pagination and clear the current list
    availableTemplates.clear();
    currentTemplatePage.value = 1;
    canLoadMoreTemplates.value = true;
    // Fetch templates with the new search query
    fetchMessageTemplates();
  }

// ADD THIS: New method to clear the search bar and refresh the list
  void clearSearch() {
    searchTemplateController.clear();
    searchQuery.value =
        ''; // This will automatically trigger the debounced search
  }

//------------------send-templated-messages-------------------------------------------------
// var availableTemplates = <String>[].obs;
// ... (rest of your existing variables)
  @override
  void onClose() {
    _stopStatusResync();
    // Stop receiving live socket events for this (now-closing) chat so
    // SocketsController never delivers into a disposed controller.
    if (Get.isRegistered<SocketsController>()) {
      Get.find<SocketsController>().unregisterOpenChat(this);
    }
    scrollController.removeListener(_scrollListener);
    scrollController.dispose();
    profileWaKey = '';
    // socket.dispose();
    for (var controller in dynamicTextControllers) {
      controller.dispose();
    }
    isScreen = '';
    EasyLoading.dismiss();
    shouldContinue = false; // Stop any ongoing operations
    searchTemplateController.dispose(); // ADD THIS LINE
    textFieldFocusNode.dispose();

    super.onClose();
  }
}