import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:getgabs/data/models/call_log_model.dart';
import 'package:getgabs/domain/controllers/dashboard/call_logs/call_logs_controller.dart';
import 'package:getgabs/ui/pages/dashboard/chats/messages_ui/messages_page.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CALL LOGS TAB — dashboard-level bottom-nav screen (Chats / Call Logs / More)
//  Backed by CallLogsController: paginated fetch + infinite scroll.
// ─────────────────────────────────────────────────────────────────────────────
class CallLogsScreen extends StatelessWidget {
  const CallLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Shared instance put by DashboardScreen (so the bottom-nav badge and
    // this screen stay in sync); fall back to put() in case this screen is
    // ever reached outside the dashboard.
    final controller = Get.isRegistered<CallLogsController>()
        ? Get.find<CallLogsController>()
        : Get.put(CallLogsController());
    final wp = MediaQuery.of(context).size.width;

    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.call, color: Colors.black87, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Call Logs',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: wp * 0.065,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                
              ],
            ),
          ),
        ),
        body: _buildBody(controller, wp),
      ),
    );
  }

  Widget _buildBody(CallLogsController controller, double w) {
    return Obx(() {
      if (controller.isLoading.value && controller.callLogs.isEmpty) {
        return const Center(
            child: CircularProgressIndicator(color: Colors.orange));
      }

      if (controller.error.value.isNotEmpty && controller.callLogs.isEmpty) {
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline, color: Colors.grey[400], size: 48),
            const SizedBox(height: 8),
            Text(controller.error.value,
                style: TextStyle(color: Colors.grey[500], fontSize: w * 0.036)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: controller.refreshCallLogs,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: TextButton.styleFrom(foregroundColor: Colors.orange),
            ),
          ]),
        );
      }

      if (controller.callLogs.isEmpty) {
        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.call_end, color: Colors.grey[300], size: 56),
            const SizedBox(height: 12),
            Text(
              'No call logs found',
              style: TextStyle(color: Colors.grey[500], fontSize: w * 0.036),
            ),
          ]),
        );
      }

      // Read explicitly (rather than only inside groupedCallLogs) so this
      // Obx re-subscribes and rebuilds when the seen-state changes via
      // markMissedCallsAsSeen(), not just when callLogs itself changes.
      controller.totalMissedCalls.value;
      final groups = controller.groupedCallLogs;

      return RefreshIndicator(
        color: Colors.orange,
        onRefresh: controller.refreshCallLogs,
        child: ListView.separated(
          controller: controller.scrollController,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: groups.length + (controller.isLoadingMore.value ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            if (index >= groups.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.orange)),
              );
            }
            final group = groups[index];
            return CallLogRow(entries: group.entries, screenW: w);
          },
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  LIST ROW
// ─────────────────────────────────────────────────────────────────────────────
class CallLogRow extends StatefulWidget {
  // Every call folded into this row (most recent first). A single-call
  // group is just a list of one.
  final List<CallLogEntry> entries;
  final double screenW;

  const CallLogRow({super.key, required this.entries, required this.screenW});

  @override
  State<CallLogRow> createState() => _CallLogRowState();
}

class _CallLogRowState extends State<CallLogRow> {
  bool _expanded = false;

  List<CallLogEntry> get _entries => widget.entries;
  CallLogEntry get entry => _entries.first;
  double get screenW => widget.screenW;
  int get callCount => _entries.length;

  static const List<Color> _avatarColors = [
    Color(0xFF7FDBC7), // teal
    Color(0xFFF6D186), // amber
    Color(0xFFC9E4A5), // light green
    Color(0xFFF3B7C2), // pink
    Color(0xFFA9C9F5), // light blue
    Color(0xFFD3B8F0), // light purple
  ];

  // Uses `.characters` (Unicode grapheme clusters) instead of raw string
  // indexing/substring — a name starting with an emoji or other multi-byte
  // character would otherwise split a surrogate pair and render as a
  // garbled glyph or throw, which showed up specifically on iPhone contact
  // names that Android devices didn't happen to trip over.
  String get _initials {
    final name = entry.customerName.trim().isNotEmpty
        ? entry.customerName.trim()
        : entry.phoneNumber;
    if (name.isEmpty) return '#';
    final words = name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '#';
    final firstChars = words[0].characters;
    final first = firstChars.isNotEmpty ? firstChars.first : '';
    if (words.length == 1) return first.toUpperCase();
    final secondChars = words[1].characters;
    final second = secondChars.isNotEmpty ? secondChars.first : '';
    return (first + second).toUpperCase();
  }

  Color get _avatarColor {
    final key = entry.customerName.isNotEmpty
        ? entry.customerName
        : entry.phoneNumber;
    final hash = key.codeUnits.fold<int>(0, (sum, c) => sum + c);
    return _avatarColors[hash % _avatarColors.length];
  }

  String get _nameLabel {
    final name =
        entry.customerName.isNotEmpty ? entry.customerName : entry.phoneNumber;
    return callCount > 1 ? '$name ($callCount)' : name;
  }

  String get _durationLabel {
    if (entry.isMissed) return '-';
    final seconds = entry.callDurationSeconds;
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '$minutes:${remaining.toString().padLeft(2, '0')}';
  }

  String get _dateTimeLabel {
    final t = entry.callTime;
    final datePart = DateFormat('MMMM d').format(t);
    final timePart = DateFormat('h:mm a').format(t).toLowerCase();
    return '$datePart at $timePart';
  }

  void _openChat() {
    final profile = entry.profile;
    if (profile == null) {
      Get.snackbar(
        'Unavailable',
        'Could not open chat for this call',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEA4335),
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        borderRadius: 10,
      );
      return;
    }
    Get.to(() => MessagesPage(
          profile: profile,
          profileWaKey: profile.profileWaKey,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = entry.isMissed ? Colors.red : const Color(0xFF1E8E5A);
    final directionColor = entry.isMissed ? Colors.red : Colors.blue.shade600;
    final directionIcon = entry.isMissed
        ? (entry.isOutgoing ? Icons.call_missed_outgoing : Icons.call_missed)
        : (entry.isOutgoing ? Icons.call_made : Icons.call_received);
    final directionLabel = entry.isMissed
        ? (entry.isOutgoing ? 'No answer' : 'Missed')
        : (entry.isOutgoing ? 'Outgoing' : 'Incoming');

    return Container(
      margin: EdgeInsets.symmetric(horizontal: screenW * 0.03),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFEEEEEE)),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: callCount > 1
                ? () => setState(() => _expanded = !_expanded)
                : null,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenW * 0.035,
                vertical: screenW * 0.03,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle, color: _avatarColor),
                    child: Text(
                      _initials,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                          fontSize: 14),
                    ),
                  ),
                  SizedBox(width: screenW * 0.03),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _nameLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: screenW * 0.038,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ),
                            if (callCount > 1) ...[
                              SizedBox(width: screenW * 0.01),
                              Icon(
                                _expanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 18,
                                color: Colors.grey[500],
                              ),
                            ],
                          ],
                        ),
                        if (entry.customerName.isNotEmpty) ...[
                          SizedBox(height: screenW * 0.006),
                          Text(
                            entry.phoneNumber,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: screenW * 0.032,
                                color: Colors.grey[500]),
                          ),
                        ],
                        SizedBox(height: screenW * 0.01),
                        Row(
                          children: [
                            Icon(directionIcon, size: 14, color: directionColor),
                            const SizedBox(width: 4),
                            Text(
                              directionLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: screenW * 0.032,
                                color: directionColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                '  |  $_dateTimeLabel',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: screenW * 0.032,
                                    color: Colors.grey[500]),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: screenW * 0.02),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _durationLabel,
                        style: TextStyle(
                            fontSize: screenW * 0.036,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87),
                      ),
                      SizedBox(height: screenW * 0.02),
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _openChat,
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(Icons.chat_bubble_outline,
                              size: 18, color: Colors.grey[500]),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (entry.hasRecording)
            Padding(
              padding: EdgeInsets.fromLTRB(
                screenW * 0.035,
                0,
                screenW * 0.035,
                screenW * 0.03,
              ),
              child: _CallRecordingSection(entry: entry, screenW: screenW),
            ),
          if (_expanded && callCount > 1) ...[
            const Divider(height: 1, color: Color(0xFFEEEEEE)),
            ..._entries.map((e) => _CallHistoryTile(entry: e, screenW: screenW)),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DROPDOWN ROW — one individual call inside an expanded group
// ─────────────────────────────────────────────────────────────────────────────
class _CallHistoryTile extends StatelessWidget {
  final CallLogEntry entry;
  final double screenW;

  const _CallHistoryTile({required this.entry, required this.screenW});

  String get _durationLabel {
    if (entry.isMissed) return '-';
    final seconds = entry.callDurationSeconds;
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '$minutes:${remaining.toString().padLeft(2, '0')}';
  }

  String get _dateTimeLabel {
    final t = entry.callTime;
    final datePart = DateFormat('MMMM d').format(t);
    final timePart = DateFormat('h:mm a').format(t).toLowerCase();
    return '$datePart at $timePart';
  }

  @override
  Widget build(BuildContext context) {
    final directionColor = entry.isMissed ? Colors.red : Colors.blue.shade600;
    final directionIcon = entry.isMissed
        ? (entry.isOutgoing ? Icons.call_missed_outgoing : Icons.call_missed)
        : (entry.isOutgoing ? Icons.call_made : Icons.call_received);
    final directionLabel = entry.isMissed
        ? (entry.isOutgoing ? 'No answer' : 'Missed')
        : (entry.isOutgoing ? 'Outgoing' : 'Incoming');

    return Container(
      color: const Color(0xFFFAFAFA),
      padding: EdgeInsets.symmetric(
        horizontal: screenW * 0.035,
        vertical: screenW * 0.025,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(width: screenW * 0.1),
              Icon(directionIcon, size: 13, color: directionColor),
              const SizedBox(width: 4),
              Text(
                directionLabel,
                style: TextStyle(
                  fontSize: screenW * 0.03,
                  color: directionColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Expanded(
                child: Text(
                  '  |  $_dateTimeLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: screenW * 0.03, color: Colors.grey[500]),
                ),
              ),
              Text(
                _durationLabel,
                style: TextStyle(
                    fontSize: screenW * 0.03,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54),
              ),
            ],
          ),
          if (entry.hasRecording) ...[
            SizedBox(height: screenW * 0.02),
            Padding(
              padding: EdgeInsets.only(left: screenW * 0.1),
              child: _CallRecordingSection(entry: entry, screenW: screenW),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  RECORDING + TRANSCRIPT — shown under a call whose recording was stored
//  (recording_status == 'stored'). `*_wasabi_path` values from the API are
//  relative, so CallLogEntry already turns them into absolute URLs off
//  ApiEndPoints.mediaStorageBaseUrl.
// ─────────────────────────────────────────────────────────────────────────────
class _CallRecordingSection extends StatefulWidget {
  final CallLogEntry entry;
  final double screenW;

  const _CallRecordingSection({required this.entry, required this.screenW});

  @override
  State<_CallRecordingSection> createState() => _CallRecordingSectionState();
}

class _CallRecordingSectionState extends State<_CallRecordingSection> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isBuffering = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  // Local cached copy of the recording — Android's native media player
  // (used by audioplayers for UrlSource) streams via the OS's old bundled
  // HTTP client, which fails the TLS handshake against this server on
  // ranged/seek requests. Downloading with Dart's http client (unaffected —
  // different TLS stack) and playing the local file sidesteps that entirely.
  String? _localAudioPath;

  bool _transcriptVisible = false;
  bool _transcriptLoading = false;
  // null = not fetched yet.
  CallTranscript? _transcript;
  String? _transcriptError;

  CallLogEntry get entry => widget.entry;
  double get screenW => widget.screenW;

  @override
  void initState() {
    super.initState();
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isBuffering) return;
    try {
      if (_isPlaying) {
        await _player.pause();
        if (mounted) setState(() => _isPlaying = false);
        return;
      }

      var localPath = _localAudioPath;
      if (localPath == null) {
        setState(() => _isBuffering = true);
        final response = await http.get(Uri.parse(entry.recordingUrl!));
        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode}');
        }
        final dir = await getTemporaryDirectory();
        final fileName =
            'call_recording_${entry.id.isNotEmpty ? entry.id : entry.recordingUrl.hashCode}.ogg';
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        localPath = file.path;
        _localAudioPath = localPath;
      }

      await _player.play(DeviceFileSource(localPath));
      if (mounted) setState(() => _isPlaying = true);
    } catch (e) {
      debugPrint('❌ recording playback failed for ${entry.recordingUrl}: $e');
      if (mounted) {
        // A TLS handshake failure here has consistently traced back to the
        // device's own DNS/network filtering (e.g. a filtering DNS provider
        // intercepting the storage domain) rather than anything the app can
        // fix — surfacing that distinctly saves a repeat of that debugging.
        final isHandshakeFailure =
            e is HandshakeException || e.toString().contains('Handshake');
        Get.snackbar(
          'Playback failed',
          isHandshakeFailure
              ? 'Could not play this recording — check your device\'s network or DNS settings (e.g. a filtering DNS provider may be blocking it)'
              : 'Could not play this recording',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: const Color(0xFFEA4335),
          colorText: Colors.white,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 5),
        );
      }
    } finally {
      if (mounted) setState(() => _isBuffering = false);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleTranscript() async {
    setState(() => _transcriptVisible = !_transcriptVisible);
    if (_transcriptVisible && _transcript == null && !_transcriptLoading) {
      await _loadTranscript();
    }
  }

  Future<void> _loadTranscript() async {
    if (!entry.hasTranscript) {
      setState(() => _transcript = CallTranscript.empty());
      return;
    }
    setState(() {
      _transcriptLoading = true;
      _transcriptError = null;
    });
    try {
      final response = await http.get(Uri.parse(entry.transcriptUrl!));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        setState(() => _transcript = decoded is Map<String, dynamic>
            ? CallTranscript.fromJson(decoded)
            : CallTranscript.empty());
      } else {
        setState(() =>
            _transcriptError = 'Could not load transcript (${response.statusCode})');
      }
    } catch (e) {
      debugPrint('❌ transcript fetch failed for ${entry.transcriptUrl}: $e');
      final isHandshakeFailure =
          e is HandshakeException || e.toString().contains('Handshake');
      setState(() => _transcriptError = isHandshakeFailure
          ? "Could not load transcript — check your device's network or DNS "
              'settings (e.g. a filtering DNS provider may be blocking it)'
          : 'Could not load transcript');
    } finally {
      if (mounted) setState(() => _transcriptLoading = false);
    }
  }

  void _copyTranscript() {
    final transcript = _transcript;
    if (transcript == null || transcript.isEmpty) return;
    String text;
    if (transcript.segments.isNotEmpty) {
      text = transcript.segments
          .map((s) =>
              '${s.speaker} (${_formatTranscriptTime(s.start)}): ${s.text}')
          .join('\n');
    } else {
      text = transcript.rawText;
    }
    Clipboard.setData(ClipboardData(text: text));
    Get.snackbar(
      'Copied',
      'Transcript copied to clipboard',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
    );
  }

  Future<void> _downloadFile(String url, {required String label}) async {
    EasyLoading.show(status: 'Downloading...');
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');

      final directory = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download')
          : await getApplicationDocumentsDirectory();
      if (!await directory.exists()) await directory.create(recursive: true);

      final fileName = url.split('/').last;
      await File('${directory.path}/$fileName').writeAsBytes(response.bodyBytes);

      EasyLoading.dismiss();
      Get.snackbar(
        'Downloaded',
        '$label saved to ${directory.path}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
      );
    } catch (e) {
      EasyLoading.dismiss();
      Get.snackbar(
        'Failed',
        'Could not download $label',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFEA4335),
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!entry.hasRecording) return const SizedBox.shrink();

    final maxSeconds =
        _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1.0;
    final posSeconds = _position.inSeconds.toDouble().clamp(0.0, maxSeconds);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: screenW * 0.02,
            vertical: screenW * 0.015,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F7F7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.mic_none, size: 16, color: Colors.grey[500]),
              SizedBox(width: screenW * 0.02),
              InkWell(
                onTap: _togglePlay,
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.black87,
                  child: _isBuffering
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(_isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 16, color: Colors.white),
                ),
              ),
              SizedBox(width: screenW * 0.02),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                  ),
                  child: Slider(
                    min: 0,
                    max: maxSeconds,
                    value: posSeconds,
                    activeColor: Colors.black54,
                    inactiveColor: Colors.grey[300],
                    onChanged: (v) => _player.seek(Duration(seconds: v.toInt())),
                  ),
                ),
              ),
              Text(
                '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                style: TextStyle(fontSize: screenW * 0.028, color: Colors.grey[600]),
              ),
              SizedBox(width: screenW * 0.02),
              InkWell(
                onTap: () => _downloadFile(entry.recordingUrl!, label: 'Recording'),
                child:
                    Icon(Icons.download_outlined, size: 18, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        if (entry.hasTranscript) ...[
          SizedBox(height: screenW * 0.02),
          InkWell(
            onTap: _toggleTranscript,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: screenW * 0.025,
                vertical: screenW * 0.012,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F6F1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1E8E5A).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.subtitles_outlined,
                      size: 14, color: Color(0xFF1E8E5A)),
                  SizedBox(width: screenW * 0.01),
                  Text(
                    _transcriptVisible ? 'Hide transcript' : 'Show transcript',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E8E5A),
                    ),
                  ),
                  Icon(
                    _transcriptVisible
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 16,
                    color: const Color(0xFF1E8E5A),
                  ),
                ],
              ),
            ),
          ),
          if (_transcriptVisible) ...[
            SizedBox(height: screenW * 0.02),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border.all(color: Colors.grey[200]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenW * 0.025,
                      vertical: screenW * 0.015,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                'TRANSCRIPT',
                                style: TextStyle(
                                  fontSize: screenW * 0.026,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey[500],
                                  letterSpacing: 0.4,
                                ),
                              ),
                              if ((_transcript?.language.isNotEmpty ?? false)) ...[
                                SizedBox(width: screenW * 0.015),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    _transcript!.language.toUpperCase(),
                                    style: TextStyle(
                                        fontSize: screenW * 0.024,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey[600]),
                                  ),
                                ),
                              ],
                              if (_transcript != null &&
                                  _transcript!.durationSeconds > 0) ...[
                                SizedBox(width: screenW * 0.015),
                                Text(
                                  '·  ${_formatTranscriptTime(_transcript!.durationSeconds)}'
                                  '  ·  ${(_transcript!.confidence * 100).round()}%',
                                  style: TextStyle(
                                    fontSize: screenW * 0.026,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: (_transcript?.isEmpty == false)
                              ? _copyTranscript
                              : null,
                          child: Row(
                            children: [
                              Icon(Icons.copy, size: 13, color: Colors.grey[500]),
                              const SizedBox(width: 3),
                              Text('Copy',
                                  style: TextStyle(
                                      fontSize: screenW * 0.028,
                                      color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: Colors.grey[200]),
                  Padding(
                    padding: EdgeInsets.all(screenW * 0.025),
                    child: _transcriptLoading
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          )
                        : (_transcriptError != null
                            ? Text(_transcriptError!,
                                style: TextStyle(
                                    fontSize: screenW * 0.032,
                                    color: Colors.red[400]))
                            : ((_transcript?.isEmpty ?? true)
                                ? Text(
                                    'The transcript is empty — the call audio '
                                    'may have been too quiet or in an '
                                    'unsupported language.',
                                    style: TextStyle(
                                      fontSize: screenW * 0.032,
                                      color: Colors.grey[500],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  )
                                : SizedBox(
                                    height: screenW * 0.9,
                                    child: ListView.separated(
                                      padding: EdgeInsets.zero,
                                      itemCount: _transcript!.segments.length,
                                      separatorBuilder: (_, __) =>
                                          SizedBox(height: screenW * 0.02),
                                      itemBuilder: (context, i) =>
                                          _TranscriptBubble(
                                        segment: _transcript!.segments[i],
                                        screenW: screenW,
                                      ),
                                    ),
                                  ))),
                  ),
                ],
              ),
            ),
            SizedBox(height: screenW * 0.015),
            InkWell(
              onTap: () =>
                  _downloadFile(entry.transcriptUrl!, label: 'Transcript JSON'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.description_outlined, size: 12, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    'Download raw JSON',
                    style: TextStyle(
                      fontSize: screenW * 0.028,
                      color: Colors.grey[500],
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

String _formatTranscriptTime(double seconds) {
  final totalSeconds = seconds.round();
  final minutes = totalSeconds ~/ 60;
  final secs = totalSeconds % 60;
  return '$minutes:${secs.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
//  TRANSCRIPT BUBBLE — one speaker turn, chat-style (Business right/green,
//  Customer left/white), matching the diarized segments the transcript JSON
//  returns.
// ─────────────────────────────────────────────────────────────────────────────
class _TranscriptBubble extends StatelessWidget {
  final TranscriptSegment segment;
  final double screenW;

  const _TranscriptBubble({required this.segment, required this.screenW});

  @override
  Widget build(BuildContext context) {
    final isBusiness = segment.isBusiness;
    final bubbleColor = isBusiness ? const Color(0xFFDCF8C6) : Colors.white;
    final crossAlign =
        isBusiness ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final mainAlign = isBusiness ? MainAxisAlignment.end : MainAxisAlignment.start;

    return Column(
      crossAxisAlignment: crossAlign,
      children: [
        Row(
          mainAxisAlignment: mainAlign,
          children: [
            Icon(isBusiness ? Icons.storefront : Icons.person,
                size: 12, color: Colors.grey[600]),
            SizedBox(width: screenW * 0.01),
            Text(
              segment.speaker,
              style: TextStyle(
                fontSize: screenW * 0.028,
                fontWeight: FontWeight.w700,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(width: screenW * 0.015),
            Text(
              _formatTranscriptTime(segment.start),
              style: TextStyle(fontSize: screenW * 0.026, color: Colors.grey[500]),
            ),
          ],
        ),
        SizedBox(height: screenW * 0.006),
        Row(
          mainAxisAlignment: mainAlign,
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: screenW * 0.72),
              padding: EdgeInsets.symmetric(
                horizontal: screenW * 0.03,
                vertical: screenW * 0.018,
              ),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(10),
                border: isBusiness ? null : Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                segment.text,
                style: TextStyle(fontSize: screenW * 0.033, color: Colors.black87),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
