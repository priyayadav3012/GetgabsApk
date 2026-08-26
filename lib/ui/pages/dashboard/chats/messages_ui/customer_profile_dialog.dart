import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:getgabs/domain/controllers/dashboard/dashboard_controller.dart';
import 'package:getgabs/domain/controllers/dashboard/messages_page/messages_page_controller.dart';
import 'package:getgabs/domain/services/remote_services/chat_service.dart';
import 'package:getgabs/ui/pages/dashboard/chats/active_chats/active_chat_list_tile.dart';
import 'package:getgabs/ui/pages/dashboard/chats/messages_ui/assign_to_teammate_dialog.dart';
import 'package:getgabs/ui/themes/themes.dart';

void showCustomerProfileDialog(MessagesPageController messagesPageController) {
  Get.to(() =>
      CustomerProfileDialog(messagesPageController: messagesPageController));
}

class CustomerProfileDialog extends StatefulWidget {
  final MessagesPageController messagesPageController;

  const CustomerProfileDialog({super.key, required this.messagesPageController});

  @override
  State<CustomerProfileDialog> createState() => _CustomerProfileDialogState();
}

class _CustomerProfileDialogState extends State<CustomerProfileDialog> {
  bool _isEditing = false;
  late final TextEditingController _nameController;

  final ChatServices _chatServices = ChatServices();
  bool _isLoadingCoAssignees = true;
  List<String> _coAssignedNames = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
        text: widget.messagesPageController.userProfile.value.profileName);
    _loadCoAssignees();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadCoAssignees() async {
    try {
      final dc = Get.find<DashboardController>();
      final token = await dc.getPartnerSessionToken();
      if (token == null) {
        debugPrint('⚠️ getCoAssignees: no session token, skipping');
        if (mounted) setState(() => _isLoadingCoAssignees = false);
        return;
      }
      final response = await _chatServices.getCoAssigneesService(
        customerKey: widget.messagesPageController.profileWaKey,
        token: token,
      );
      // Confirmed shape: {"status":true,"co_assignees":[{"id","name",
      // "username","co_assignment_id"}]}
      final list = (response is Map ? response['co_assignees'] : null) as List?;
      final names = (list ?? [])
          .map((e) => e is Map
              ? (e['name'] ?? e['user_name'] ?? e['username'])?.toString()
              : e?.toString())
          .whereType<String>()
          .where((n) => n.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _coAssignedNames = names;
        _isLoadingCoAssignees = false;
      });
    } catch (e) {
      debugPrint('⚠️ getCoAssignees error: $e');
      if (!mounted) return;
      setState(() => _isLoadingCoAssignees = false);
    }
  }

  Future<void> _save() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      EasyLoading.showError('Name cannot be empty');
      return;
    }
    EasyLoading.show(status: 'Saving...');
    final ok = await widget.messagesPageController.updateCustomerName(newName);
    EasyLoading.dismiss();
    if (ok) {
      setState(() => _isEditing = false);
      EasyLoading.showSuccess('Name updated');
    }
  }

  void _openAssignDialog(profile) {
    // Shown as an overlay on top of this screen (not a page navigation),
    // so closing it comes right back here — it used to pop this screen
    // first, which meant closing the assign dialog landed back on the
    // chat screen underneath instead of this profile screen.
    showAssignToTeammateDialog(
      customerKey: widget.messagesPageController.profileWaKey,
      customerName: profile.profileName,
      customerPhone: profile.profileWaId.toString(),
      messagesPageController: widget.messagesPageController,
      isAlreadyAssignedToAgent: profile.assignedUserId != null,
      currentAssignedAgentId: profile.assignedUserId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = AppTheme.appThemeColor;
    return Obx(() {
      final profile = widget.messagesPageController.userProfile.value;
      final safeName = cleanName(profile.profileName);
      final mc = widget.messagesPageController;

      return Scaffold(
        backgroundColor: AppTheme.whiteColor,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                // ---- Back button (no Material AppBar) ----
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: AppTheme.blackColor),
                        onPressed: () => Get.back(),
                      ),
                    ],
                  ),
                ),
                // ---- Header (plain white, normal look) ----
                Theme(
                  data: Theme.of(context).copyWith(
                    iconTheme: const IconThemeData(color: AppTheme.blackColor),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
                    color: AppTheme.whiteColor,
                    child: Column(
                      children: [
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: getAvatarBgColor(safeDecode(safeName)),
                        child: Text(
                          getInitialsSafe(safeName),
                          style: TextStyle(
                            color: getAvatarTextColor(safeDecode(safeName)),
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_isEditing)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: TextField(
                            controller: _nameController,
                            autofocus: true,
                            textAlign: TextAlign.center,
                            maxLength: 80,
                            style: const TextStyle(
                                color: AppTheme.blackColor, fontSize: 17),
                            cursorColor: themeColor,
                            decoration: InputDecoration(
                              hintText: 'Customer name',
                              hintStyle: const TextStyle(color: AppTheme.greyColor),
                              isDense: true,
                              counterText: '',
                              enabledBorder: const UnderlineInputBorder(
                                  borderSide: BorderSide(color: AppTheme.primaryBoarderColor)),
                              focusedBorder: UnderlineInputBorder(
                                  borderSide: BorderSide(color: themeColor)),
                            ),
                          ),
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                profile.profileName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.blackColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => setState(() => _isEditing = true),
                              child: Icon(Icons.edit,
                                  size: 17, color: themeColor),
                            ),
                          ],
                        ),
                      const SizedBox(height: 4),
                      Text(
                        profile.profileWaId.toString(),
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.greyColor),
                      ),
                      if (_isEditing) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppTheme.primaryBoarderColor),
                                  foregroundColor: AppTheme.blackColor,
                                ),
                                onPressed: () {
                                  _nameController.text = profile.profileName;
                                  setState(() => _isEditing = false);
                                },
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeColor,
                                  foregroundColor: AppTheme.whiteColor,
                                ),
                                onPressed: _save,
                                child: const Text('Save'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                ),
                const Divider(height: 1),

                // ---- Body ----
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick actions: Assign Chat + Pause/Resume AI
                      Row(
                        children: [
                          Expanded(
                            child: _ActionTile(
                              icon: Icons.person_add_alt_1,
                              label: 'Assign Chat',
                              color: themeColor,
                              onTap: () => _openAssignDialog(profile),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: mc.isAiToggleLoading.value
                                ? const _ActionTile(
                                    icon: null,
                                    label: 'Please wait',
                                    color: AppTheme.greyColor,
                                    onTap: null,
                                    isLoading: true,
                                  )
                                : _ActionTile(
                                    icon: mc.isAiPaused.value
                                        ? Icons.play_circle_outline
                                        : Icons.pause_circle_outline,
                                    label: mc.isAiPaused.value
                                        ? 'Resume AI'
                                        : 'Pause AI',
                                    color: mc.isAiPaused.value
                                        ? const Color(0xFF2196F3)
                                        : const Color(0xFFFF5722),
                                    onTap: mc.toggleAiPause,
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _InfoRow(
                        icon: Icons.person_outline,
                        label: 'Assigned to',
                        value: profile.assignedUserName ??
                            profile.assignedTeamName ??
                            'Not assigned',
                        themeColor: themeColor,
                        action: TextButton(
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                          onPressed: () => _openAssignDialog(profile),
                          child: Text(
                            profile.assignedUserId == null ? 'Assign' : 'Change',
                            style: TextStyle(
                                color: themeColor, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _InfoRow(
                        icon: Icons.group_outlined,
                        label: 'Co-assigned',
                        themeColor: themeColor,
                        valueWidget: _isLoadingCoAssignees
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                _coAssignedNames.isEmpty
                                    ? 'None'
                                    : _coAssignedNames.join(', '),
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _ActionTile extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool isLoading;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: color),
                  )
                : Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? valueWidget;
  final Widget? action;
  final Color themeColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.themeColor,
    this.value,
    this.valueWidget,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: themeColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: themeColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.greyColor)),
              const SizedBox(height: 2),
              valueWidget ??
                  Text(value ?? '',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}
