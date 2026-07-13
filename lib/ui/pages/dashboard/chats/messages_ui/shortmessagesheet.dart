import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getgabs/domain/controllers/dashboard/messages_page/messages_page_controller.dart';

// ============================================================
// MODEL
// ============================================================
class ShortMessage {
  final int id;
  final String templateName;
  final String templateData;
  final String category;

  ShortMessage({
    required this.id,
    required this.templateName,
    required this.templateData,
    required this.category,
  });

  factory ShortMessage.fromJson(Map<String, dynamic> json) {
    return ShortMessage(
      id:           json['id'] ?? 0,
      templateName: json['template_name']?.toString() ?? '',
      templateData: json['template_data']?.toString() ?? '',
      category:     json['template_category']?.toString() ?? '',
    );
  }

  String get messageBody {
    try {
      final decoded = jsonDecode(templateData);
      final textBody = decoded['text']?['body']?.toString();
      if (textBody != null && textBody.isNotEmpty) return textBody;
      final components = decoded['template']?['components'];
      if (components != null) {
        for (var comp in components) {
          if (comp['type'] == 'BODY') {
            return comp['text']?.toString() ?? templateName;
          }
        }
      }
      final interactiveBody = decoded['interactive']?['body']?['text']?.toString();
      if (interactiveBody != null && interactiveBody.isNotEmpty) return interactiveBody;
      return templateName;
    } catch (_) {
      return templateName;
    }
  }
}

// ============================================================
// BOTTOM SHEET
// ============================================================
class ShortMessageSheet extends StatefulWidget {
  final MessagesPageController controller;

  const ShortMessageSheet({super.key, required this.controller});

  static void show(MessagesPageController controller) {
    controller.fetchShortMessages(page: 1);
    Get.bottomSheet(
      ShortMessageSheet(controller: controller),
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
    );
  }

  @override
  State<ShortMessageSheet> createState() => _ShortMessageSheetState();
}

class _ShortMessageSheetState extends State<ShortMessageSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<ShortMessage> _allMessages = [];
  List<ShortMessage> _filteredMessages = [];
  String _searchQuery = '';
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    ever(widget.controller.shortMessages, (_) {
      if (mounted) _rebuildList();
    });
    _rebuildList();
  }

  void _rebuildList() {
    final raw = widget.controller.shortMessages;
    final messages = raw
        .map((e) => ShortMessage.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    if (mounted) {
      setState(() {
        _allMessages = messages;
        _applyFilter();
      });
    }
  }

  void _applyFilter() {
    _filteredMessages = _searchQuery.isEmpty
        ? List.from(_allMessages)
        : _allMessages.where((m) {
            return m.templateName.toLowerCase().contains(_searchQuery) ||
                m.messageBody.toLowerCase().contains(_searchQuery);
          }).toList();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      _searchQuery = query;
      _applyFilter();
    });
    // If user is searching, fetch a larger page size to include results across pagination
    if (query.isNotEmpty) {
      widget.controller.fetchShortMessages(page: 1, paginate: 1000);
    } else {
      // restore default paging when search cleared
      widget.controller.fetchShortMessages(page: 1);
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // SEND
  // ============================================================
  Future<void> _sendShortMessage(ShortMessage msg) async {
    try {
      setState(() => _isSending = true);

      final userData     = widget.controller.userData;
      final chatServices = widget.controller.chatServices;

      final parentUserId  = await userData.getParentUserId();
      final currentUserId = await userData.getLoggedInUserId();
      final apiKey        = await userData.getApiKey();
      final userPrivilage = await userData.getUserPrivilage();
      final userRole      = await userData.getUserRole();

      final effectiveParentId =
          (parentUserId == '0' || parentUserId.isEmpty)
              ? currentUserId.toString()
              : parentUserId;

      final Map<String, dynamic> jsonData = {
        "parent_user_id":    effectiveParentId,
        "current_user_id":   currentUserId.toString(),
        "api_key":           apiKey,
        "customer_key":      widget.controller.profileWaKey,
        "messageType":       "servicetemplate",
        "shortCutMessageId": msg.id,
        "current_user_role": userRole,
        "user_privilage":    userPrivilage,
      };

      final Map<String, String> headers = {
        "X-Client-GetGabs": apiKey.toString(),
        "Content-Type":     "application/json",
      };

      debugPrint('📤 Sending: $jsonData');
      final response = await chatServices.sendShortMessageService(
          jsonData, headers: headers);
      debugPrint('📤 Response: $response');

      Get.back();

      if (response['status'] == true) {
        widget.controller.currentPage.value = 1;
        widget.controller.messageChatList.clear();
        widget.controller.groupedMessages.clear();
        widget.controller.loadChatsApi(
          userKey: widget.controller.profileWaKey,
          from: 'outside',
        );
      } else {
        Get.snackbar(
          'Error',
          response['message']?.toString() ?? 'Failed to send',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFEA4335),
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
          borderRadius: 10,
        );
      }
    } catch (e) {
      debugPrint('❌ sendShortMessage error: $e');
      Get.back();
      Get.snackbar('Error', 'Something went wrong',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFEA4335),
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
          borderRadius: 10);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    final mq      = MediaQuery.of(context);
    final screenH = mq.size.height;
    final screenW = mq.size.width;

    double sheetHeight = screenH * 0.72 - mq.viewInsets.bottom;
    if (sheetHeight < screenH * 0.3) sheetHeight = screenH * 0.3;

    return SizedBox(
      height: sheetHeight,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Scaffold(
          backgroundColor: Colors.white,
          resizeToAvoidBottomInset: false,
          body: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  width: screenW * 0.1,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: screenW * 0.04, vertical: 4),
                child: Row(children: [
                  const Icon(Icons.flash_on, color: Colors.black87, size: 20),
                  SizedBox(width: screenW * 0.02),
                  Text('Shortcut Messages',
                      style: TextStyle(
                          fontSize: screenW * 0.042,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Obx(() {
                    final loading =
                        widget.controller.isShortMessagesLoading.value;
                    return (loading || _isSending)
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.orange))
                        : IconButton(
                            icon: const Icon(Icons.refresh,
                                color: Colors.grey, size: 22),
                            onPressed: () =>
                                widget.controller.fetchShortMessages(page: 1));
                  }),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey, size: 22),
                    onPressed: Get.back,
                  ),
                ]),
              ),

              // Search
              Padding(
                padding: EdgeInsets.fromLTRB(
                    screenW * 0.04, 4, screenW * 0.04, 4),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search shortcuts...',
                    hintStyle: TextStyle(
                        color: Colors.grey[400], fontSize: screenW * 0.034),
                    prefixIcon:
                        const Icon(Icons.search, color: Colors.grey, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.grey, size: 18),
                            onPressed: _searchController.clear)
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: Colors.orange)),
                  ),
                  style: TextStyle(fontSize: screenW * 0.034),
                ),
              ),

              // Tip
              Padding(
                padding: EdgeInsets.fromLTRB(
                    screenW * 0.04, 4, screenW * 0.04, 6),
                child: Row(children: [
                  Text('Tip: Type  ',
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: screenW * 0.029)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(4)),
                    child: Text('/',
                        style: TextStyle(
                            fontSize: screenW * 0.032,
                            fontWeight: FontWeight.w700)),
                  ),
                  Flexible(
                    child: Text(
                      '  in message box to search shortcuts',
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: screenW * 0.029),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]),
              ),

              const Divider(height: 1, color: Color(0xFFEEEEEE)),

              // List
              Expanded(child: _buildBody(screenW)),

              // Pagination
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              _buildPagination(screenW),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(double w) {
    return Obx(() {
      final loading = widget.controller.isShortMessagesLoading.value;
      final error   = widget.controller.shortMessagesError.value;

      if (loading && _allMessages.isEmpty) {
        return const Center(
            child: CircularProgressIndicator(color: Colors.orange));
      }

      if (error.isNotEmpty && _allMessages.isEmpty) {
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline, color: Colors.grey[400], size: 44),
            const SizedBox(height: 8),
            Text(error,
                style: TextStyle(
                    color: Colors.grey[500], fontSize: w * 0.033)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () =>
                  widget.controller.fetchShortMessages(page: 1),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style:
                  TextButton.styleFrom(foregroundColor: Colors.orange),
            ),
          ]),
        );
      }

      if (_filteredMessages.isEmpty) {
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.flash_off, color: Colors.grey[300], size: 44),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No results for "$_searchQuery"'
                  : 'No shortcut messages found',
              style: TextStyle(
                  color: Colors.grey[500], fontSize: w * 0.033),
            ),
          ]),
        );
      }

      return ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: _filteredMessages.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
        itemBuilder: (context, index) => _ShortMessageTile(
          msg: _filteredMessages[index],
          screenW: w,
          onTap: () => _sendShortMessage(_filteredMessages[index]),
        ),
      );
    });
  }

  // ✅ Pagination — controller se driven
  Widget _buildPagination(double w) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: w * 0.04, vertical: 10),
        child: Obx(() {
          final currentPage =
              widget.controller.shortMessagesCurrentPage.value;
          final totalPages =
              widget.controller.shortMessagesTotalPages.value;

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Page $currentPage of $totalPages',
                style: TextStyle(
                    color: Colors.grey[600], fontSize: w * 0.033),
              ),
              Row(children: [
                _pageBtn(
                  label: 'Previous',
                  enabled: currentPage > 1,
                  onTap: () => widget.controller
                      .fetchShortMessages(page: currentPage - 1),
                  w: w,
                ),
                SizedBox(width: w * 0.025),
                _pageBtn(
                  label: 'Next',
                  enabled: currentPage < totalPages,
                  onTap: () => widget.controller
                      .fetchShortMessages(page: currentPage + 1),
                  w: w,
                ),
              ]),
            ],
          );
        }),
      ),
    );
  }

  Widget _pageBtn({
    required String label,
    required bool enabled,
    required VoidCallback onTap,
    required double w,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: w * 0.045, vertical: w * 0.022),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color:
                enabled ? Colors.grey.shade400 : Colors.grey.shade200,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: w * 0.033,
            color: enabled ? Colors.black87 : Colors.grey[400],
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// LIST TILE
// ============================================================
class _ShortMessageTile extends StatelessWidget {
  final ShortMessage msg;
  final VoidCallback onTap;
  final double screenW;

  const _ShortMessageTile({
    required this.msg,
    required this.onTap,
    required this.screenW,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        debugPrint('🟠 Tapped: ${msg.templateName}');
        onTap();
      },
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: screenW * 0.04,
          vertical: screenW * 0.035,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '/ ',
              style: TextStyle(
                fontSize: screenW * 0.038,
                fontWeight: FontWeight.w700,
                color: Colors.grey[700],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    msg.templateName,
                    style: TextStyle(
                      fontSize: screenW * 0.038,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: screenW * 0.008),
                  Text(
                    msg.messageBody,
                    style: TextStyle(
                      fontSize: screenW * 0.033,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}