import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getgabs/data/get_storage/get_storage.dart';
import 'package:getgabs/data/models/message_modal.dart';
import 'package:getgabs/domain/controllers/dashboard/dashboard_controller.dart';
import 'package:getgabs/domain/controllers/dashboard/messages_page/messages_page_controller.dart';
import 'package:getgabs/domain/services/remote_services/chat_service.dart';
import 'package:getgabs/ui/themes/themes.dart';

enum _AssignMode { agent, team }

enum _ChatStatus { open, closed }

class _AssignOption {
  final int id;
  final String name;
  final String? username;
  final String? role;
  final String? teamName;
  final int? membersCount;
  const _AssignOption(
    this.id,
    this.name, {
    this.username,
    this.role,
    this.teamName,
    this.membersCount,
  });
}

/// Builds a full diagnostic string from a /partners/ error response instead
/// of just `message` — includes the per-field `errors` map (see the
/// "Validation Error" shape in postman/assign_chat_apis.postman_collection.json)
/// and falls back to the raw response so nothing the backend actually said
/// is ever swallowed. Check `flutter logs` / the debug console for the full
/// request+response — every call is tagged "🔎 [<apiName>]".
String _extractErrorMessage(dynamic response) {
  if (response is! Map) return response.toString();
  final parts = <String>[];
  final message = response['message']?.toString();
  if (message != null && message.isNotEmpty) parts.add(message);

  final errors = response['errors'];
  if (errors is Map) {
    errors.forEach((field, fieldErrors) {
      if (fieldErrors is List) {
        parts.add('$field: ${fieldErrors.join(', ')}');
      } else {
        parts.add('$field: $fieldErrors');
      }
    });
  }

  if (parts.isEmpty) return response.toString();
  return parts.join('\n');
}

void showAssignToTeammateDialog({
  required String customerKey,
  required String customerName,
  required String customerPhone,
  required MessagesPageController messagesPageController,
  bool isAlreadyAssignedToAgent = false,
  int? currentAssignedAgentId,
}) {
  Get.dialog(
    AssignToTeammateDialog(
      customerKey: customerKey,
      customerName: customerName,
      customerPhone: customerPhone,
      messagesPageController: messagesPageController,
      isAlreadyAssignedToAgent: isAlreadyAssignedToAgent,
      currentAssignedAgentId: currentAssignedAgentId,
    ),
  );
}

class AssignToTeammateDialog extends StatefulWidget {
  final String customerKey;
  final String customerName;
  final String customerPhone;
  final MessagesPageController messagesPageController;
  // When the customer-list API already reports an assigned_user for this
  // chat, "Assign to" is pre-filled with that agent (still re-selectable)
  // and "Co-assign to" is also offered. When not yet assigned, only
  // "Assign to" is shown — Co-assign doesn't apply without a primary assignee.
  final bool isAlreadyAssignedToAgent;
  final int? currentAssignedAgentId;

  const AssignToTeammateDialog({
    super.key,
    required this.customerKey,
    required this.customerName,
    required this.customerPhone,
    required this.messagesPageController,
    this.isAlreadyAssignedToAgent = false,
    this.currentAssignedAgentId,
  });

  @override
  State<AssignToTeammateDialog> createState() =>
      _AssignToTeammateDialogState();
}

class _AssignToTeammateDialogState extends State<AssignToTeammateDialog> {
  final TextEditingController _commentController = TextEditingController();
  final ChatServices _chatServices = ChatServices();
  final GetStorageUserData _userData = GetStorageUserData();

  _AssignMode _mode = _AssignMode.agent;
  _ChatStatus _status = _ChatStatus.open;

  int? _assignAgentId;
  int? _coAssignAgentId;
  int? _teamId;

  bool _isLoadingAgentOptions = false;
  bool _isLoadingTeamOptions = false;
  bool _isSubmitting = false;
  String? _agentOptionsError;
  String? _teamOptionsError;
  List<_AssignOption> _agentOptions = [];
  List<_AssignOption> _teamOptions = [];

  @override
  void initState() {
    super.initState();
    _assignAgentId = widget.currentAssignedAgentId;
    _fetchAgentOptions();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  DashboardController get _dashboardController =>
      Get.find<DashboardController>();

  Future<String?> _getToken({bool forceRefresh = false}) {
    return _dashboardController.getPartnerSessionToken(
        forceRefresh: forceRefresh);
  }

  void _selectMode(_AssignMode mode) {
    if (_mode == mode) return;
    setState(() => _mode = mode);
    if (mode == _AssignMode.team &&
        _teamOptions.isEmpty &&
        _teamOptionsError == null &&
        !_isLoadingTeamOptions) {
      _fetchTeamOptions();
    }
  }

  Future<void> _fetchAgentOptions() async {
    setState(() {
      _isLoadingAgentOptions = true;
      _agentOptionsError = null;
    });
    try {
      final token = await _getToken();
      if (token == null) {
        if (!mounted) return;
        setState(() {
          _isLoadingAgentOptions = false;
          _agentOptionsError = 'Unable to load list. Please try again.';
        });
        return;
      }

      final response = await _chatServices.fetchExecutiveListService(token);
      if (response['status'] != true) {
        if (!mounted) return;
        setState(() {
          _isLoadingAgentOptions = false;
          _agentOptionsError = _extractErrorMessage(response);
        });
        return;
      }

      final list = response['ExecutiveList'] as List? ?? [];
      final parsed = list.map((u) {
        final teams = u['teams'] as List?;
        final firstTeamName = (teams != null && teams.isNotEmpty)
            ? teams.first['name']?.toString()
            : null;
        return _AssignOption(
          int.tryParse(u['id'].toString()) ?? 0,
          u['name']?.toString() ?? '',
          username: u['username']?.toString(),
          role: u['role']?.toString(),
          teamName: firstTeamName,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _agentOptions = parsed;
        _isLoadingAgentOptions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingAgentOptions = false;
        _agentOptionsError = 'Something went wrong. Please try again.';
      });
    }
  }

  Future<void> _fetchTeamOptions() async {
    setState(() {
      _isLoadingTeamOptions = true;
      _teamOptionsError = null;
    });
    try {
      final token = await _getToken();
      if (token == null) {
        if (!mounted) return;
        setState(() {
          _isLoadingTeamOptions = false;
          _teamOptionsError = 'Unable to load list. Please try again.';
        });
        return;
      }

      final response = await _chatServices.listTeamsService(token);
      if (response['status'] != true) {
        if (!mounted) return;
        setState(() {
          _isLoadingTeamOptions = false;
          _teamOptionsError = _extractErrorMessage(response);
        });
        return;
      }

      // Real response uses 'data', not 'teams' as the API doc suggested
      // (confirmed via Postman) — id/name/members_count shape matches.
      final teams = response['data'] as List? ?? [];
      final parsed = teams
          .map((t) => _AssignOption(
                int.tryParse(t['id'].toString()) ?? 0,
                t['name']?.toString() ?? '',
                membersCount: int.tryParse(t['members_count'].toString()),
              ))
          .toList();

      if (!mounted) return;
      setState(() {
        _teamOptions = parsed;
        _isLoadingTeamOptions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingTeamOptions = false;
        _teamOptionsError = 'Something went wrong. Please try again.';
      });
    }
  }

  /// The note card's top-right name should reflect WHO THIS SPECIFIC ACTION
  /// TARGETS (the agent/team just picked in the dropdown) — not whoever's
  /// currently logged in performing the assign, which is the same person
  /// every time and was the actual bug (every note showed one repeated name
  /// no matter which teammate got assigned).
  String _nameForOption(List<_AssignOption> options, int? id) {
    if (id == null) return '';
    for (final o in options) {
      if (o.id == id) return o.name;
    }
    return '';
  }

  bool get _canSubmit {
    if (_isSubmitting) return false;
    if (_mode == _AssignMode.team) return _teamId != null;
    // Agent mode allows either field on its own — Co-Assign can be used
    // without a primary "Assign to" pick (that's why the two fields are
    // mutually exclusive), so the button must not require both.
    return _assignAgentId != null || _coAssignAgentId != null;
  }

  /// Runs [call] with [token]; if the response looks like an auth failure,
  /// fetches a fresh token once and retries — mirrors DashboardController.addCustomer's retry pattern.
  Future<dynamic> _callWithRetry(
      Future<dynamic> Function(String token) call, String token) async {
    var response = await call(token);
    if (response['status'] != true) {
      final msg = response['message']?.toString().toLowerCase() ?? '';
      final looksLikeAuthFailure = msg.contains('token') ||
          msg.contains('auth') ||
          msg.contains('unauthor');
      if (looksLikeAuthFailure) {
        final freshToken = await _getToken(forceRefresh: true);
        if (freshToken != null) {
          response = await call(freshToken);
        }
      }
    }
    return response;
  }

  /// [noteType] is forced onto the parsed note rather than trusted from the
  /// backend — note_type has already come back missing/inconsistent with
  /// the API doc, so the app decides the card's header label (ASSIGNMENT /
  /// CO-ASSIGNMENT / etc.) from which action it just called, not from that field.
  ///
  /// [targetName] is the note card's top-right name — the agent/team this
  /// specific action just targeted (resolved via [_nameForOption] from the
  /// dropdown selection). The backend's own note_created_by is NOT used
  /// even when present — confirmed via real API responses it comes back
  /// as a fixed generic value (e.g. "Michael from Getgabs") on every
  /// assign, unrelated to who was actually assigned.
  ///
  /// [content] replaces the backend's own note content for the same reason
  /// — confirmed via real API responses (assign to id 48402 = "Rajat
  /// Sharma") that the backend still writes body text like "Assigned to
  /// getgabs", the account name, not the actual assignee's name, even
  /// though it assigned the correct id. The id-based assignment itself is
  /// correct; only the human-readable text fields are wrong.
  void _insertNoteIfPresent(dynamic response,
      {required String noteType,
      required String targetName,
      required String content}) {
    final note = response['note'];
    if (note is Map) {
      try {
        final message = Message.fromJson(Map<String, dynamic>.from(note))
            .copyWith(
                noteType: noteType,
                noteCreatedBy: targetName,
                messageText: content);
        widget.messagesPageController.insertNoteMessage(message);
      } catch (e) {
        debugPrint('⚠️ Could not render assignment note: $e');
      }
    }
  }

  Future<void> _onAssignPressed() async {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);
    try {
      final token = await _getToken();
      if (token == null) {
        _showError('Unable to assign right now. Please try again.');
        return;
      }

      final comment = _commentController.text.trim();
      final displayName = await _userData.getCurrentDisplayName();

      if (_mode == _AssignMode.team) {
        final response = await _callWithRetry(
            (t) => _chatServices.assignTeamService({
                  'profile_wa_key': widget.customerKey,
                  'team_id': _teamId.toString(),
                  'comment': comment,
                  'token': t,
                }),
            token);

        if (response['status'] == true) {
          final teamName = _nameForOption(_teamOptions, _teamId);
          final resolvedTeamName = teamName.isNotEmpty ? teamName : displayName;
          _insertNoteIfPresent(response,
              noteType: 'team_assignment',
              targetName: resolvedTeamName,
              content: 'Assigned to $resolvedTeamName team');
          Get.back();
          Get.snackbar(
            'Chat Assigned',
            response['message']?.toString() ?? 'Assigned successfully.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppTheme.appThemeColor,
            colorText: AppTheme.whiteColor,
          );
        } else {
          _showError(_extractErrorMessage(response));
        }
        return;
      }

      // Co-Assign is usable on its own (that's why the two fields are
      // mutually exclusive) — only call the primary agent-assign if
      // "Assign to" actually has a value.
      if (_assignAgentId == null) {
        final coAssigneeName = _nameForOption(_agentOptions, _coAssignAgentId);
        final resolvedCoAssigneeName =
            coAssigneeName.isNotEmpty ? coAssigneeName : displayName;
        final coAssignResponse = await _callWithRetry(
            (t) => _chatServices.addCoAssignService({
                  'customerKey': widget.customerKey,
                  'coAssignUserIdd': _coAssignAgentId.toString(),
                  // The backend just echoes this straight into note.content
                  // /co_assigned_to.name verbatim — no lookup of its own —
                  // so this must be the friendly display name, not the raw
                  // login username, or the note reads "Co-assigned to
                  // LakshyaF" instead of "Co-assigned to Lakshya".
                  'usernameIs': resolvedCoAssigneeName,
                  'comment': comment,
                  'token': t,
                }),
            token);

        if (coAssignResponse['status'] == true) {
          _insertNoteIfPresent(coAssignResponse,
              noteType: 'team_co_assignment',
              targetName: resolvedCoAssigneeName,
              content: 'Co-assigned to $resolvedCoAssigneeName');
          Get.back();
          Get.snackbar(
            'Chat Assigned',
            coAssignResponse['message']?.toString() ?? 'Co-assigned successfully.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppTheme.appThemeColor,
            colorText: AppTheme.whiteColor,
          );
        } else {
          _showError(_extractErrorMessage(coAssignResponse));
        }
        return;
      }

      // Agent mode — primary assign first, then an optional co-assign.
      final assigneeName = _nameForOption(_agentOptions, _assignAgentId);
      final resolvedAssigneeName =
          assigneeName.isNotEmpty ? assigneeName : displayName;
      final assignResponse = await _callWithRetry(
          (t) => _chatServices.updateLastSummaryAssignService({
                'customerKey': widget.customerKey,
                'assigToUserIdd': _assignAgentId.toString(),
                // See the co-assign call above — the backend echoes this
                // verbatim into note.content/assigned_to.name, so it must
                // be the friendly display name, not the raw username.
                'usernameIs': resolvedAssigneeName,
                'comment': comment,
                'windowType': _status == _ChatStatus.open ? 'opened' : 'closed',
                'token': t,
              }),
          token);

      if (assignResponse['status'] != true) {
        _showError(_extractErrorMessage(assignResponse));
        return;
      }
      _insertNoteIfPresent(assignResponse,
          noteType: 'team_assignment',
          targetName: resolvedAssigneeName,
          content: 'Assigned to $resolvedAssigneeName\n\n'
              'Status: ${_status == _ChatStatus.open ? 'Open' : 'Closed'}');

      if (_coAssignAgentId == null) {
        Get.back();
        Get.snackbar(
          'Chat Assigned',
          assignResponse['message']?.toString() ?? 'Assigned successfully.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.appThemeColor,
          colorText: AppTheme.whiteColor,
        );
        return;
      }

      final coAssigneeName = _nameForOption(_agentOptions, _coAssignAgentId);
      final resolvedCoAssigneeName =
          coAssigneeName.isNotEmpty ? coAssigneeName : displayName;
      final coAssignResponse = await _callWithRetry(
          (t) => _chatServices.addCoAssignService({
                'customerKey': widget.customerKey,
                'coAssignUserIdd': _coAssignAgentId.toString(),
                'usernameIs': resolvedCoAssigneeName,
                'comment': comment,
                'token': t,
              }),
          token);

      Get.back();
      if (coAssignResponse['status'] == true) {
        _insertNoteIfPresent(coAssignResponse,
            noteType: 'team_co_assignment',
            targetName: resolvedCoAssigneeName,
            content: 'Co-assigned to $resolvedCoAssigneeName');
        Get.snackbar(
          'Chat Assigned',
          'Agent assigned and co-assigned successfully.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.appThemeColor,
          colorText: AppTheme.whiteColor,
        );
      } else {
        Get.snackbar(
          'Partially Assigned',
          'Agent assigned, but co-assign failed: ${_extractErrorMessage(coAssignResponse)}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFF59E0B),
          colorText: AppTheme.whiteColor,
          duration: const Duration(seconds: 6),
        );
      }
    } catch (e) {
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    Get.snackbar(
      'Error',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFFEA4335),
      colorText: AppTheme.whiteColor,
      duration: const Duration(seconds: 6),
      isDismissible: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final coAssignOptions =
        _agentOptions.where((o) => o.id != _assignAgentId).toList();

    return Dialog(
      backgroundColor: AppTheme.whiteColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Assign to Teammate',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  InkWell(
                    onTap: () => Get.back(),
                    child: const Icon(Icons.close, size: 20, color: AppTheme.greyColor),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Route this conversation to a teammate for follow-up.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFDCE8FF),
                      child: Text(
                        widget.customerName.isNotEmpty
                            ? widget.customerName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Color(0xFF3B6FE0), fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.customerName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15)),
                          Text(widget.customerPhone,
                              style: const TextStyle(
                                  fontSize: 12, color: AppTheme.greyColor)),
                        ],
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDEDED),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('user',
                          style: TextStyle(fontSize: 12, color: AppTheme.greyColor)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Write Your Comment Here',
                  hintStyle: const TextStyle(color: AppTheme.greyColor, fontSize: 13),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppTheme.appThemeColor),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(child: _buildModeChip(_AssignMode.agent)),
                    Expanded(child: _buildModeChip(_AssignMode.team)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_mode == _AssignMode.agent) ...[
                // "Assign to" is always shown — pre-filled with the current
                // assignee when already assigned, but still re-selectable.
                // "Co-assign to" only makes sense once there's a primary
                // assignee, so it's only shown when already assigned.
                const Text('Assign to',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                _SearchableOptionField(
                  key: const ValueKey('assign_agent'),
                  placeholder: 'Select Agent',
                  searchHint: 'Search agent...',
                  isLoading: _isLoadingAgentOptions,
                  errorText: _agentOptionsError,
                  onRetry: _fetchAgentOptions,
                  options: _agentOptions,
                  selectedId: _assignAgentId,
                  onChanged: (id) => setState(() => _assignAgentId = id),
                ),
                const SizedBox(height: 16),
                if (widget.isAlreadyAssignedToAgent) ...[
                  const Text('Co-assign to',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  _SearchableOptionField(
                    key: const ValueKey('co_assign_agent'),
                    placeholder: 'Select Agent',
                    searchHint: 'Search agent...',
                    isLoading: _isLoadingAgentOptions,
                    errorText: _agentOptionsError,
                    onRetry: _fetchAgentOptions,
                    options: coAssignOptions,
                    selectedId: _coAssignAgentId,
                    onChanged: (id) => setState(() => _coAssignAgentId = id),
                  ),
                  const SizedBox(height: 16),
                ],
              ] else ...[
                const Text('Assign to Team',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                _SearchableOptionField(
                  key: const ValueKey('assign_team'),
                  placeholder: 'Select Team',
                  searchHint: 'Search team...',
                  isLoading: _isLoadingTeamOptions,
                  errorText: _teamOptionsError,
                  onRetry: _fetchTeamOptions,
                  options: _teamOptions,
                  selectedId: _teamId,
                  isTeamStyle: true,
                  onChanged: (id) => setState(() => _teamId = id),
                ),
                const SizedBox(height: 16),
              ],
              const Text('Mark as',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                      child: _buildStatusButton(
                          'Open', _ChatStatus.open, const Color(0xFF1FAA59))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _buildStatusButton(
                          'Closed', _ChatStatus.closed, AppTheme.greyColor)),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Get.back(),
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFF0F0F0),
                      foregroundColor: AppTheme.blackColor,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _canSubmit ? _onAssignPressed : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF034737),
                      disabledBackgroundColor: const Color(0xFFBDBDBD),
                      foregroundColor: AppTheme.whiteColor,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTheme.whiteColor),
                          )
                        : const Text('Assign'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeChip(_AssignMode mode) {
    final selected = _mode == mode;
    final label = mode == _AssignMode.agent ? 'Agent' : 'Team';
    final icon = mode == _AssignMode.agent
        ? Icons.person_add_alt_1
        : Icons.groups_outlined;

    return GestureDetector(
      onTap: () => _selectMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppTheme.whiteColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? AppTheme.blackColor : AppTheme.greyColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? AppTheme.blackColor : AppTheme.greyColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(String label, _ChatStatus status, Color activeColor) {
    final selected = _status == status;
    return GestureDetector(
      onTap: () => setState(() => _status = status),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? activeColor.withOpacity(0.1) : AppTheme.whiteColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? activeColor : const Color(0xFFE0E0E0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.circle, size: 10, color: selected ? activeColor : AppTheme.greyColor),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, color: selected ? activeColor : AppTheme.blackColor, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Self-contained searchable picker field — open/search state lives here so
/// the Agent-mode dialog can show two independent instances at once
/// ("Assign to" and "Co-assign to") without them fighting over shared state.
class _SearchableOptionField extends StatefulWidget {
  final String placeholder;
  final String searchHint;
  final bool isLoading;
  final String? errorText;
  final VoidCallback onRetry;
  final List<_AssignOption> options;
  final int? selectedId;
  final bool isTeamStyle;
  final ValueChanged<int?> onChanged;

  const _SearchableOptionField({
    super.key,
    required this.placeholder,
    required this.searchHint,
    required this.isLoading,
    required this.errorText,
    required this.onRetry,
    required this.options,
    required this.selectedId,
    required this.onChanged,
    this.isTeamStyle = false,
  });

  @override
  State<_SearchableOptionField> createState() => _SearchableOptionFieldState();
}

class _SearchableOptionFieldState extends State<_SearchableOptionField> {
  bool _isOpen = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _AssignOption? selected;
    for (final o in widget.options) {
      if (o.id == widget.selectedId) {
        selected = o;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isOpen = !_isOpen),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      selected?.name ?? widget.placeholder,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: selected == null ? AppTheme.greyColor : AppTheme.blackColor,
                      ),
                    ),
                  ),
                ),
              ),
              if (selected != null)
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => widget.onChanged(null),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 16, color: AppTheme.greyColor),
                  ),
                ),
              GestureDetector(
                onTap: () => setState(() => _isOpen = !_isOpen),
                child: Icon(
                  _isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: AppTheme.greyColor,
                ),
              ),
            ],
          ),
        ),
        if (_isOpen) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: widget.searchHint,
                      hintStyle: const TextStyle(color: AppTheme.greyColor, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.greyColor),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                    ),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE0E0E0)),
                _buildList(),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildList() {
    if (widget.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (widget.errorText != null) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Text(widget.errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
            TextButton(onPressed: widget.onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }

    final filtered = _searchQuery.isEmpty
        ? widget.options
        : widget.options
            .where((o) => o.name.toLowerCase().contains(_searchQuery))
            .toList();

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          widget.options.isEmpty
              ? (widget.isTeamStyle ? 'No teams found.' : 'No agents found.')
              : 'No results match your search.',
          style: const TextStyle(color: AppTheme.greyColor, fontSize: 13),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final option = filtered[index];
          final isSelected = option.id == widget.selectedId;
          return InkWell(
            onTap: () {
              widget.onChanged(option.id);
              setState(() => _isOpen = false);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: isSelected ? const Color(0xFFF5F5F5) : Colors.transparent,
              child: widget.isTeamStyle ? _buildTeamRow(option) : _buildAgentRow(option),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTeamRow(_AssignOption option) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(option.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              if (option.membersCount != null)
                Text('${option.membersCount} members',
                    style: const TextStyle(fontSize: 11, color: AppTheme.greyColor)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAgentRow(_AssignOption option) {
    return Row(
      children: [
        Expanded(
          child: Text(option.name,
              overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
        ),
        if (option.teamName != null) ...[
          _buildPill(option.teamName!,
              icon: Icons.groups, bg: const Color(0xFFF3E8FF), fg: const Color(0xFF8B5CF6)),
          const SizedBox(width: 6),
        ],
        if (option.role != null && option.role!.isNotEmpty)
          _buildPill(_titleCase(option.role!),
              bg: _roleBadgeColor(option.role!), fg: AppTheme.whiteColor),
      ],
    );
  }

  Widget _buildPill(String label, {IconData? icon, required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: fg),
            const SizedBox(width: 3),
          ],
          Text(label, style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Color _roleBadgeColor(String role) {
    final r = role.toLowerCase();
    if (r.contains('admin')) return const Color(0xFF8B5CF6);
    if (r.contains('manager')) return const Color(0xFF16A34A);
    return AppTheme.greyColor;
  }

  String _titleCase(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}
