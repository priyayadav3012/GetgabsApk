// File: lib/domain/services/whatsapp_calling_service.dart
// ✅ UNIFIED FILE — Works for both Android & iOS

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:flutter_webrtc/flutter_webrtc.dart' hide navigator;
import 'package:get/get.dart';
import 'package:getgabs/domain/end_points/api_end_points.dart';
import 'package:getgabs/ui/themes/themes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client_new/socket_io_client_new.dart' as IO;
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';
import 'package:vibration/vibration.dart';

final _uuidFactory = Uuid();

String normalizeCallKitId(String? id) {
  if (id == null || id.trim().isEmpty) return _uuidFactory.v4();

  final normalized = id.trim().toLowerCase();
  final uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  if (uuidRegex.hasMatch(normalized)) return normalized;

  return _uuidFactory.v5(Uuid.NAMESPACE_URL, normalized).toLowerCase();
}

class WhatsAppCallingService {
  final int userId;
  final int adminId;
  final String userRole;
  final String businessApiKey;
  // Identity used to join the live call socket. For most users this equals
  // userId; for a privilege-1 sub-user (or 'manager') it's the admin's id,
  // since the WhatsApp Business number's incoming-call events are routed to
  // whoever owns it. userId itself is left untouched everywhere else
  // (HTTP call attribution — callerId/acceptedBy — must stay the real actor).
  final int socketUserId;

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  IO.Socket? socket;
  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;

  // #changedWithJClaude — ICE candidate buffer: candidates generated before the socket
  // reconnects (background → foreground transition) are queued here and flushed the
  // moment onConnect fires. Without this they were silently dropped and WebRTC could
  // never establish a peer connection even though SDP exchange succeeded via HTTP.
  final List<Map<String, dynamic>> _bufferedIceCandidates = [];

  // Buffer for REMOTE ICE candidates (from caller) that arrive via socket BEFORE
  // _createPeerConnection() runs. On first call, the socket may already be delivering
  // 'ice_candidate' events while peerConnection is still null; if we drop them here
  // the callee never learns the caller's ICE addresses and ICE never completes.
  // Drained in answerCall() after setRemoteDescription() so the peer connection is
  // ready to accept them. Cleared in cleanupCall() for next call.
  final List<RTCIceCandidate> _pendingRemoteCandidates = [];

  // ✅ iOS ke liye valid UUID store karna zaroori hai
  String? currentCallKitId;

  AudioPlayer? _ringtonePlayer;
  bool _isRinging = false;
  bool isGlobalListener = false;

  // ✅ Duplicate CallKit screen rokne ke liye
  bool _callKitShowing = false;

  bool _isCallActive = false;
  bool get isCallActive => _isCallActive;

  // ✅ Call accept ho gaya — socket event ignore karo
  bool _callAccepted = false;
  bool get callAccepted => _callAccepted;

  String? currentCallId;
  String? incomingSdp;
  String callStatus = 'Waiting for calls...';

  String? _pendingSdp;
  String? _pendingCallId;
  bool _hasActivePendingCall = false;

  DateTime? callStartTime;
  bool _callStartLogged = false;
  String? currentPhoneNumber;
  String? currentCallerName;
  bool isOutgoingCall = false;

  Timer? _callTimeoutTimer;
  static const int callTimeoutSeconds = 60;

  Function(String)? onStatusChange;
  Function(MediaStream?)? onRemoteStream;
  Function()? onCallEnded;
  Function(String)? onError;
  Function(Map<String, dynamic>)? onIncomingCall;

  static Future<String?> Function(String phoneNumber)? contactNameLookup;

  static const String socketUrl = 'https://calling.getgabs.com';
  static const String apiBaseUrl =
      'https://app.getgabs.com/v2/flutterapplication';

  static const Map<String, dynamic> iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun.relay.metered.ca:80'},
      {
        'urls': 'turn:global.relay.metered.ca:80',
        'username': '8033d76c7cc0cf98cfd739b2',
        'credential': 'jlae48TwFJY4X8Lq',
      },
      {
        'urls': 'turn:global.relay.metered.ca:80?transport=tcp',
        'username': '8033d76c7cc0cf98cfd739b2',
        'credential': 'jlae48TwFJY4X8Lq',
      },
      {
        'urls': 'turn:global.relay.metered.ca:443',
        'username': '8033d76c7cc0cf98cfd739b2',
        'credential': 'jlae48TwFJY4X8Lq',
      },
      {
        'urls': 'turns:global.relay.metered.ca:443?transport=tcp',
        'username': '8033d76c7cc0cf98cfd739b2',
        'credential': 'jlae48TwFJY4X8Lq',
      },
    ],
    'iceCandidatePoolSize': 10,
  };

  WhatsAppCallingService({
    required this.userId,
    required this.adminId,
    required this.userRole,
    required this.businessApiKey,
    int? socketUserId,
  }) : socketUserId = socketUserId ?? userId;

  String? get pendingSdp => _pendingSdp;
  String? get pendingCallId => _pendingCallId;
  bool get hasActivePendingCall => _hasActivePendingCall;

  void _clearPendingState() {
    _pendingSdp = null;
    _pendingCallId = null;
    _hasActivePendingCall = false;
    _bufferedIceCandidates.clear();
    _pendingRemoteCandidates.clear();
  }

  void _cancelCallTimeout() {
    _callTimeoutTimer?.cancel();
    _callTimeoutTimer = null;
  }

  void _startCallTimeout() {
    _cancelCallTimeout();
    _callTimeoutTimer = Timer(const Duration(seconds: callTimeoutSeconds), () {
      _updateStatus('No answer');
      onError?.call('No answer');
      terminateCall();
    });
  }

  void setPendingCall({
    required String callId,
    required String sdp,
  }) {
    _pendingCallId = callId;
    _pendingSdp = sdp;
    _hasActivePendingCall = true;
    // ✅ iOS: _callAccepted = false (set hoga answerCall pe)
    // ✅ Android: same behavior — foreground mein answerCall call karega
    currentCallId = callId;
    incomingSdp = sdp;
    debugPrint('✅ setPendingCall: callId=$callId');
  }

  // ============================================
  // HELPER — iOS ke liye valid UUID banana
  // ============================================
  String _getValidCallKitId(String? id) {
    return normalizeCallKitId(id);
  }

  String _formatPhoneNumber(String phone) {
    phone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (!phone.startsWith('+')) {
      if (phone.startsWith('91') && phone.length == 12) {
        phone = '+$phone';
      } else if (phone.length == 10) {
        phone = '+91$phone';
      } else if (phone.length == 12) {
        phone = '+91${phone.substring(2)}';
      }
    }
    return phone;
  }

  String _formatDisplayNumber(String phone) {
    if (phone.isEmpty) return 'Unknown';
    String cleaned = phone.replaceAll('+', '');
    if (cleaned.startsWith('91') && cleaned.length == 12) {
      return '+91 ${cleaned.substring(2, 7)} ${cleaned.substring(7)}';
    }
    return phone;
  }

  Future<bool> _requestPermissions() async {
    final permissions = [Permission.microphone];
    Map<Permission, PermissionStatus> statuses = await permissions.request();
    if (statuses[Permission.microphone] != PermissionStatus.granted) {
      throw Exception(
          'Microphone permission denied. Please allow microphone access in Settings.');
    }
    debugPrint('✅ Permissions granted');
    return true;
  }

  Future<void> initialize() async {
    socket = IO.io(
      socketUrl,
      IO.OptionBuilder()
          .setTransports(['polling'])
          .setAuth({'userId': socketUserId, 'adminId': adminId, 'role': userRole})
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(999)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .build(),
    );
    _setupSocketListeners();
    socket!.connect();
  }

  void _setupSocketListeners() {
    socket!.on('whatsapp_call_incoming', (data) async {
      developer.log('📞 ========== INCOMING CALL ==========');
      developer.log('📞 Data: $data');

      // On iOS: also block if _hasActivePendingCall is true.
      // This catches the race window where the socket reconnects and the server
      // replays whatsapp_call_incoming BEFORE answerCall() has set _callAccepted = true.
      // On Android: socket whatsapp_call_incoming IS the primary call trigger,
      // so only _callAccepted blocks — _hasActivePendingCall must not block it.
      if (_callAccepted || (Platform.isIOS && _hasActivePendingCall)) {
        debugPrint(
            '⚠️ Call already accepted/pending — ignoring duplicate socket event');
        return;
      }

      String callerName = '';
      String callerNumber = data['from']?.toString() ?? '';

      try {
        final contactDetails = data['contactFullDetails'];
        if (contactDetails != null) {
          final profile = contactDetails['profile'];
          if (profile != null && profile['name'] != null) {
            callerName = profile['name'].toString().trim();
          }
        }
      } catch (e) {
        developer.log('📞 contactFullDetails parse error: $e');
      }

      if (callerName.isEmpty) {
        final nameFields = [
          'callerName',
          'caller_name',
          'name',
          'displayName',
          'pushName',
          'notify'
        ];
        for (String field in nameFields) {
          if (data[field] != null && data[field].toString().trim().isNotEmpty) {
            callerName = data[field].toString().trim();
            break;
          }
        }
      }

      if (callerName.isEmpty && contactNameLookup != null) {
        try {
          final lookupName = await contactNameLookup!(callerNumber);
          if (lookupName != null && lookupName.isNotEmpty) {
            callerName = lookupName;
          }
        } catch (e) {
          developer.log('📞 Contact lookup error: $e');
        }
      }

      if (callerName.isEmpty) callerName = _formatDisplayNumber(callerNumber);

      developer.log('📞 FINAL - Name: "$callerName", Number: "$callerNumber"');

      final callData = {
        'callId': data['callId']?.toString() ?? '',
        'from': callerNumber,
        'callerName': callerName,
        'sdpOffer': data['sdpOffer']?.toString() ?? '',
      };

      _clearPendingState();
      _pendingCallId = callData['callId'];
      _pendingSdp = callData['sdpOffer'];
      currentCallId = _pendingCallId;
      incomingSdp = _pendingSdp;
      currentPhoneNumber = callData['from'];
      currentCallerName = callData['callerName'];
      isOutgoingCall = false;
      _isCallActive = true;
      _hasActivePendingCall = true;
      _callAccepted = false;

      _updateStatus('Incoming call from ${callData['callerName']}');

      if (onIncomingCall != null) {
        onIncomingCall!(callData);
      } else if (isGlobalListener && Platform.isIOS) {
        // iOS: VoIP push (PushKit) owns the CallKit UI — skip _showCallKitForIncoming
        // to avoid racing CallManager's CXProvider. But still persist the call data
        // to SharedPreferences here, because the VoIP push payload typically does not
        // include the SDP/session. onNativeCallAnswered reads pending_call_session to
        // get the SDP; without this write it fails with "session missing".
        final sdpOffer = callData['sdpOffer']?.toString() ?? _pendingSdp ?? '';
        final callKitId =
            _getValidCallKitId(callData['callId']?.toString() ?? '');
        currentCallKitId = callKitId;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            'pending_call_id', callData['callId']?.toString() ?? '');
        await prefs.setString('pending_callkit_id', callKitId);
        await prefs.setString(
            'pending_caller_name', callData['callerName']?.toString() ?? '');
        await prefs.setString(
            'pending_caller_number', callData['from']?.toString() ?? '');
        // Only write session when SDP is non-empty. An empty SDP produces a
        // valid JSON string that passes the sessionStr.isEmpty check in
        // onNativeCallAnswered, causing setRemoteDescription to fail silently.
        if (sdpOffer.isNotEmpty) {
          final sessionJson = jsonEncode({'sdp': sdpOffer, 'sdp_type': 'offer'});
          await prefs.setString('pending_call_session', sessionJson);
          // Unblock onNativeCallAnswered if it arrived before this write finished
          // (background: socket reconnected after user already accepted the call).
          WhatsAppCallingConfig.notifySessionAvailable(sessionJson);
          debugPrint('✅ iOS: call data persisted from socket — VoIP push handles UI');
        } else {
          debugPrint('⚠️ iOS socket: SDP empty — skipping session write, onNativeCallAnswered will wait via Completer');
        }
      } else if (isGlobalListener) {
        await _showCallKitForIncoming(callData);
      } else {
        _showIncomingCallPopup(callData);
      }
    });

    socket!.on('call_connected', (data) async {
      _isCallActive = true;
      if (data['id'] != null) currentCallId = data['id'];
      _updateStatus('Ringing...');
      if (peerConnection != null && data['session']?['sdp'] != null) {
        try {
          await peerConnection!.setRemoteDescription(
            RTCSessionDescription(
                data['session']['sdp'], data['session']['type'] ?? 'answer'),
          );
        } catch (e) {}
      }
    });

    socket!.on('call_accepted', (data) async {
      _cancelCallTimeout();
      _isCallActive = true;
      _updateStatus('Connected');
      if (peerConnection != null && data['sdp'] != null) {
        try {
          if (peerConnection!.signalingState ==
              RTCSignalingState.RTCSignalingStateHaveLocalOffer) {
            await peerConnection!.setRemoteDescription(
                RTCSessionDescription(data['sdp'], 'answer'));
          }
        } catch (e) {}
      }
      // callStartTime and _logCallStart() fire in onIceConnectionState (Connected)
      // to avoid logging twice — once here and once when ICE confirms media flow.
    });

    socket!.on('sdp_answer', (data) async {
      _cancelCallTimeout();
      if (peerConnection != null && data['sdp'] != null) {
        try {
          await peerConnection!.setRemoteDescription(
              RTCSessionDescription(data['sdp'], 'answer'));
        } catch (e) {}
      }
    });

    socket!.on('ice_candidate', (data) async {
      final c = data['candidate'];
      if (c == null) return;
      final candidate = RTCIceCandidate(
        c['candidate'],
        c['sdpMid'],
        c['sdpMLineIndex'],
      );
      if (peerConnection != null) {
        try {
          await peerConnection!.addCandidate(candidate);
        } catch (e) {}
      } else {
        // peerConnection doesn't exist yet — buffer and drain in answerCall()
        // after setRemoteDescription(). Dropping here was the root cause of
        // first-call failure: the caller sends candidates while the callee is
        // still setting up (socket arrives before _createPeerConnection runs).
        _pendingRemoteCandidates.add(candidate);
        debugPrint(
            '📦 Remote ICE buffered (no peer connection yet): ${_pendingRemoteCandidates.length}');
      }
    });

    socket!.on('whatsapp_call_terminated', (data) async {
      _cancelCallTimeout();
      String reason =
          data is Map ? (data['reason'] ?? 'Call ended') : 'Call ended';

      final terminatedCallId = data is Map ? data['callId']?.toString() : null;
      if (terminatedCallId != null &&
          currentCallId != null &&
          terminatedCallId != currentCallId) {
        debugPrint(
            '⚠️ Ignoring stale terminated event for $terminatedCallId (current: $currentCallId)');
        return;
      }

      _updateStatus(reason);

      try {
        final prefs = await SharedPreferences.getInstance();
        final callkitId =
            currentCallKitId ?? prefs.getString('pending_callkit_id');
        if (callkitId != null && callkitId.isNotEmpty) {
          await FlutterCallkitIncoming.endCall(callkitId);
        }
      } catch (e) {
        debugPrint('❌ endCall error: $e');
      }

      await _handleCallEnded(reason);
    });

    socket!.on('call_rejected', (data) async {
      _cancelCallTimeout();
      _updateStatus(data?['reason'] ?? 'Call declined');
      try {
        final callkitId = currentCallKitId;
        if (callkitId != null) await FlutterCallkitIncoming.endCall(callkitId);
      } catch (e) {}
      await _handleCallEnded('Call declined');
    });

    socket!.on('call_failed', (data) async {
      _cancelCallTimeout();
      String reason = data?['reason'] ?? 'Call failed';
      _updateStatus(reason);
      onError?.call(reason);
      await _handleCallEnded(reason);
    });

    socket!.on('call_busy', (data) async {
      _cancelCallTimeout();
      _updateStatus('User is busy');
      await _handleCallEnded('User is busy');
    });

    socket!.on('call_unavailable', (data) async {
      _cancelCallTimeout();
      _updateStatus(data?['reason'] ?? 'User unavailable');
      await _handleCallEnded('User unavailable');
    });

    socket!.on('call_no_answer', (data) async {
      _cancelCallTimeout();
      _updateStatus('No answer');
      await _handleCallEnded('No answer');
    });

    socket!.on('call_timeout', (data) async {
      _cancelCallTimeout();
      _updateStatus('No answer');
      await _handleCallEnded('No answer');
    });

    socket!.onConnect((_) {
      debugPrint('✅ Socket connected: ${socket?.id}');
      if (!_isCallActive) _updateStatus('Connected - Ready to call');
      // Flush ICE candidates buffered during socket reconnect.
      if (_bufferedIceCandidates.isNotEmpty) {
        debugPrint(
            '🚀 Flushing ${_bufferedIceCandidates.length} buffered ICE candidates');
        for (final payload in _bufferedIceCandidates) {
          socket!.emit('ice_candidate', payload);
        }
        _bufferedIceCandidates.clear();
      }
      // Restart the ringing timeout if the socket dropped and reconnected while
      // an outgoing call is still waiting for an answer. The server may not replay
      // call_no_answer/call_timeout after a reconnect, so the caller would be
      // stuck in "Ringing..." indefinitely without a fresh timer.
      if (isOutgoingCall && _isCallActive && !_callStartLogged && _callTimeoutTimer == null) {
        debugPrint('⏱️ Restarting call timeout after socket reconnect');
        _startCallTimeout();
      }
    });

    socket!.onDisconnect((_) {
      debugPrint('❌ Socket disconnected');
      _cancelCallTimeout();
    });

    socket!
        .onReconnect((_) => debugPrint('🔄 Socket reconnected: ${socket?.id}'));
    socket!.onReconnectError((e) => debugPrint('🔄 Reconnect error: $e'));
    socket!.onError((error) {
      debugPrint('❌ Socket error: $error');
      _cancelCallTimeout();
    });
  }

  // ============================================
  // CALLKIT — GLOBAL LISTENER KE LIYE
  // ✅ iOS: UUID generate karta hai (required)
  // ✅ Android: callId directly use karta hai + AndroidParams
  // ============================================
  Future<void> _showCallKitForIncoming(Map<String, dynamic> callData) async {
    if (_callKitShowing) {
      debugPrint('⚠️ CallKit already showing — skip');
      return;
    }
    _callKitShowing = true;

    try {
      final originalCallId = callData['callId']?.toString() ?? '';
      final callerName = callData['callerName']?.toString() ?? '';
      final callerNumber = callData['from']?.toString() ?? '';
      final sdpOffer = callData['sdpOffer']?.toString() ?? _pendingSdp ?? '';

      // ✅ iOS: valid UUID chahiye CallKit ke liye
      // ✅ Android: original callId theek hai
      final callKitId =
          Platform.isIOS ? _getValidCallKitId(originalCallId) : originalCallId;

      currentCallKitId = callKitId;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_call_id', originalCallId);
      await prefs.setString('pending_callkit_id', callKitId);
      await prefs.setString('pending_caller_name', callerName);
      await prefs.setString('pending_caller_number', callerNumber);
      if (sdpOffer.isNotEmpty) {
        await prefs.setString(
          'pending_call_session',
          jsonEncode({'sdp': sdpOffer, 'sdp_type': 'offer'}),
        );
      }

      String displayName = callerName.isNotEmpty ? callerName : callerNumber;
      String displayNameShort = displayName.length > 25
          ? '${displayName.substring(0, 25)}...'
          : displayName;

      final displayForAvatar = callerName.isNotEmpty
          ? callerName
          : callerNumber.replaceAll('+', '').replaceAll(' ', '');
      final avatarUrl =
          'https://ui-avatars.com/api/?name=${Uri.encodeComponent(displayForAvatar)}&background=075E54&color=ffffff&size=200&rounded=true&bold=true';

      final params = CallKitParams(
        id: callKitId,
        nameCaller: displayNameShort,
        appName: AppTheme.currentFlavor == 'messagedly'
            ? 'Messagedly'
            : AppTheme.currentFlavor == 'scalewiz'
                ? 'Scalewiz'
                : 'GetGabs',
        avatar: avatarUrl,
        handle: callerNumber,
        type: 0,
        duration: 60000,
        // textAccept: 'Accept',
        // textDecline: 'Decline',
        // ✅ Android params — custom notification styling
        android: const AndroidParams(
          isCustomNotification: true,
          isShowLogo: false,
          ringtonePath: 'system_ringtone_default',
          backgroundColor: '#034737',
          actionColor: '#034737',
          textColor: '#ffffff',
        ),
        // ✅ iOS params — 'default' mode (voiceChat se error 561017449 aata tha)
        ios: const IOSParams(
          handleType: 'number',
          supportsVideo: false,
          audioSessionMode: 'VideoChat',
          supportsGrouping: false, // ✅ iOS Code 4 prevent karta hai
          supportsUngrouping: false,
          maximumCallGroups: 1,
          maximumCallsPerCallGroup: 1,
          configureAudioSession: true,
        ),
      );

      await FlutterCallkitIncoming.showCallkitIncoming(params);
    } catch (e) {
      debugPrint('❌ CallKit show error: $e');
      _callKitShowing = false;
      _showIncomingCallPopup(callData);
    }

    // 65 sec baad reset (call timeout ke baad)
    Future.delayed(const Duration(seconds: 65), () => _callKitShowing = false);
  }

  Future<void> _startRingtone() async {
    if (_isRinging) return;
    _isRinging = true;
    try {
      if (await Vibration.hasVibrator() == true) {
        Vibration.vibrate(pattern: [0, 1000, 500, 1000, 500, 1000], repeat: 2);
      }
      _ringtonePlayer = AudioPlayer();
      await _ringtonePlayer!.setReleaseMode(ReleaseMode.loop);
      await _ringtonePlayer!.play(AssetSource('audio/ringtone.mp3'));
    } catch (e) {
      debugPrint('🔔 Ringtone error: $e');
    }
  }

  Future<void> stopRingtone() async {
    if (!_isRinging) return;
    _isRinging = false;
    try {
      Vibration.cancel();
      await _ringtonePlayer?.stop();
      await _ringtonePlayer?.dispose();
      _ringtonePlayer = null;
    } catch (e) {
      debugPrint('🔔 Stop ringtone error: $e');
    }
  }

  void _showIncomingCallPopup(Map<String, dynamic> callData) {
    if (_callAccepted) return;
    print("call_haf_top_dialog");
    _startRingtone();
    Get.dialog(
      PopScope(
        canPop: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 50, left: 16, right: 16),
            child: Material(
              color: Colors.transparent,
              child: IncomingCallCard(
                callerName: callData['callerName'] ?? 'Unknown',
                callerNumber: callData['from'] ?? '',
                onAccept: () {
                  stopRingtone();
                  Get.back();
                  _openCallingScreenForIncoming(callData);
                },
                onDecline: () {
                  stopRingtone();
                  Get.back();
                  terminateCall();
                },
              ),
            ),
          ),
        ),
      ),
      barrierDismissible: false,
      barrierColor: Colors.black26,
    );
  }

  void _openCallingScreenForIncoming(Map<String, dynamic> callData) {
    debugPrint("call_full_dialog_incomming");
    final sdp = callData['sdpOffer'] ?? _pendingSdp;
    final callId = callData['callId'] ?? _pendingCallId;
    Get.to(
      () => IncomingCallScreen(
        callingService: this,
        callerName: callData['callerName'] ?? 'Unknown',
        callerNumber: callData['from'] ?? '',
        pendingSdp: sdp,
        pendingCallId: callId,
      ),
      transition: Transition.fadeIn,
    );
  }

  bool _isCleaningUp = false;
  // Exposed so the foreground-resume active-call recovery in main.dart can skip
  // re-pushing the call screen during the multi-second teardown window, where
  // _isCallActive still reads true but the call is actually ending.
  bool get isCleaningUp => _isCleaningUp;

  Future<void> _handleCallEnded(String reason) async {
    if (_isCleaningUp) return;
    _isCleaningUp = true;

    try {
      try {
        final prefs = await SharedPreferences.getInstance();
        final callkitId =
            currentCallKitId ?? prefs.getString('pending_callkit_id');

        if (callkitId != null && callkitId.isNotEmpty) {
          debugPrint('🧹 Cleaning up CallKit UUID: $callkitId');
          await FlutterCallkitIncoming.endCall(callkitId);
          // Also end CallManager's CXProvider call — covers the case where the
          // VoIP push arrived first and CallManager registered the UUID before
          // flutter_callkit_incoming could. FlutterCallkitIncoming.endCall only
          // dismisses its own provider; CallManager's native CallKit UI stays
          // visible until endCallProgrammatically is called for its UUID.
          if (Platform.isIOS) {
            try {
              await const MethodChannel('com.getgabs/calls')
                  .invokeMethod('endNativeCall', {'uuid': callkitId});
              debugPrint('✅ Native CallKit call ended: $callkitId');
            } catch (e) {
              debugPrint('⚠️ endNativeCall error: $e');
            }
          }
        }

        await FlutterCallkitIncoming.endAllCalls();

        await prefs.remove('pending_call_id');
        await prefs.remove('pending_call_session');
        await prefs.remove('pending_caller_name');
        await prefs.remove('pending_caller_number');
        await prefs.remove('pending_callkit_id');
        await prefs.remove('pending_from_user_id');

        debugPrint('🧹 Pending call prefs cleared');
      } catch (e) {
        debugPrint('❌ CallKit cleanup error: $e');
      }

      await stopRingtone();
      _callKitShowing = false;
      _callAccepted = false;
      _cancelCallTimeout();
      _clearPendingState();
      await _logCallEnd();
      final callEndedCallback = onCallEnded;
      await cleanupCall(); // nulls onCallEnded and other callbacks
      callEndedCallback?.call();
    } finally {
      _isCleaningUp = false;
    }
  }

  Future<void> cleanupCall() async {
    debugPrint('🧹 Starting Full Cleanup...');
    _isCallActive = false;
    _callKitShowing = false;
    _callStartLogged = false;
    _cancelCallTimeout();
    _clearPendingState();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_call_id');
      await prefs.remove('pending_callkit_id');
      await prefs.remove('pending_call_session');
      await prefs.remove('pending_caller_name');
      await prefs.remove('pending_caller_number');
      await prefs.remove('pending_from_user_id');
      debugPrint('✅ SharedPreferences Cleared');
    } catch (e) {
      debugPrint('❌ Pref cleanup error: $e');
    }

    try {
      if (localStream != null) {
        for (var track in localStream!.getTracks()) await track.stop();
        await localStream!.dispose();
      }
      await remoteStream?.dispose();
      await peerConnection?.close();
      await peerConnection?.dispose();
    } catch (e) {
      debugPrint('⚠️ Stream cleanup warning: $e');
    }

    // Reset speakerphone to earpiece so the audio route doesn't bleed into the
    // next call or app audio if the user had toggled speaker during this call.
    try { Helper.setSpeakerphoneOn(false); } catch (_) {}

    peerConnection = null;
    localStream = null;
    remoteStream = null;
    currentCallKitId = null;
    currentCallId = null;
    incomingSdp = null;
    callStartTime = null;
    currentPhoneNumber = null;
    currentCallerName = null;
    isOutgoingCall = false;
    _callAccepted = false;
    onStatusChange = null;
    onRemoteStream = null;
    onCallEnded = null;
    onError = null;
    onIncomingCall = null;

    // Tell native AppDelegate the call has ended so the isCallActive guard is
    // lifted and the next incoming VoIP push is handled normally.
    if (Platform.isIOS) {
      try {
        await const MethodChannel('com.getgabs/calls')
            .invokeMethod('markCallEnded');
        debugPrint('✅ Native notified: markCallEnded');
      } catch (e) {
        debugPrint('⚠️ markCallEnded channel error: $e');
      }
    }

    _updateStatus('Ready');
  }

  Future<void> _createPeerConnection() async {
    try {
      if (localStream != null) {
        for (var track in localStream!.getTracks()) await track.stop();
        await localStream!.dispose();
      }
    } catch (e) {}
    try {
      await remoteStream?.dispose();
    } catch (e) {}
    try {
      await peerConnection?.close();
      await peerConnection?.dispose();
    } catch (e) {}

    peerConnection = null;
    peerConnection = await createPeerConnection(iceServers);

    peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams[0];
        onRemoteStream?.call(remoteStream);
      }
    };

    // #changedWithJClaude — buffer ICE candidates when socket is not yet connected.
    // In background→foreground transitions the socket reconnects after setLocalDescription
    // already triggers candidate generation, so we queue and flush on onConnect.
    peerConnection!.onIceCandidate = (candidate) {
      // Diagnose STUN/TURN: log candidate type so failures are visible in console.
      // host   = local network candidate (always present, no STUN/TURN needed)
      // srflx  = STUN worked (public IP discovered)
      // relay  = TURN worked (media will route through relay server)
      // If you only ever see 'host' and call fails → STUN/TURN is broken.
      final raw = candidate.candidate ?? '';
      final type = raw.contains('typ relay')
          ? '🔁 relay (TURN)'
          : raw.contains('typ srflx')
              ? '🌐 srflx (STUN)'
              : raw.contains('typ host')
                  ? '🏠 host'
                  : '❓ unknown';
      debugPrint(
          '🧊 ICE candidate: $type | ${raw.split(' ').take(6).join(' ')}');

      if (currentCallId == null) return;
      final payload = {
        'callId': currentCallId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      };
      if (socket?.connected == true) {
        socket!.emit('ice_candidate', payload);
      } else {
        _bufferedIceCandidates.add(payload);
        debugPrint(
            '📦 ICE candidate buffered (socket not ready): ${_bufferedIceCandidates.length} queued');
      }
    };

    peerConnection!.onIceConnectionState = (state) {
      debugPrint('🧊 ICE state → $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        _cancelCallTimeout();
        if (!_callStartLogged) {
          _callStartLogged = true;
          callStartTime = DateTime.now();
          _logCallStart();
        }
        // Tell CallKit the outgoing call is now connected, so the Recents
        // entry reflects an actual answered call (started via startCall() in
        // makeCall()) rather than one that looks abandoned/unanswered.
        if (isOutgoingCall && currentCallKitId != null) {
          FlutterCallkitIncoming.setCallConnected(currentCallKitId!)
              .catchError((e) => debugPrint('⚠️ CallKit setCallConnected error: $e'));
        }
        _updateStatus('Connected');
        _isCallActive = true;
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        // Temporary loss (background/network blip). Do NOT end the call —
        // WebRTC will attempt ICE restart automatically. Surface a status
        // update so the UI shows "Reconnecting..." rather than freezing silently.
        _updateStatus('Reconnecting...');
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _cancelCallTimeout();
        onError?.call('Connection failed');
        _handleCallEnded('Connection failed');
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateClosed) {
        _handleCallEnded('Call ended');
      }
    };
  }

  // Serializes concurrent answer attempts. onNativeCallAnswered answers the
  // call directly in the background (locked-phone CallKit accept), while
  // WhatsAppCallingScreen._initCall may call answerCall() again once the app
  // foregrounds. Both can pass the _callAccepted guard because that flag is
  // only set after the async _requestPermissions() — without this in-flight
  // flag two peer connections could be created for the same call.
  bool _answerCallInProgress = false;

  Future<void> answerCall() async {
    if (_answerCallInProgress) {
      debugPrint('⚠️ answerCall already in progress — skipping duplicate');
      return;
    }
    _answerCallInProgress = true;
    try {
      await _answerCallInternal();
    } finally {
      _answerCallInProgress = false;
    }
  }

  Future<void> _answerCallInternal() async {
    print("call_answerrrrrrrrrrrrrrrrrrrrrrrrrrrrr");

    if (_callAccepted) {
      debugPrint('⚠️ CALL ALREADY ACCEPTED');
      return;
    }

    if (!_hasActivePendingCall ||
        _pendingSdp == null ||
        _pendingCallId == null) {
      throw Exception('No active incoming call');
    }

    if (businessApiKey.isEmpty) {
      throw Exception('WhatsApp Business API key not configured. Please contact your admin.');
    }

    String safeSdp = _pendingSdp!;
    String safeCallId = _pendingCallId!;

    // Request permissions BEFORE marking call accepted — if denied the flags
    // stay false and the service is still clean (no cleanupCall needed).
    await _requestPermissions();

    incomingSdp = safeSdp;
    currentCallId = safeCallId;
    _isCallActive = true;
    _callAccepted = true;

    // Tell native AppDelegate that a call is now active so any delayed VoIP
    // retry push is blocked from creating a second CallKit incoming-call UI.
    // This is critical for socket-originated calls where AppDelegate never ran
    // pushRegistry and its isCallActive flag is still false.
    if (Platform.isIOS) {
      try {
        await const MethodChannel('com.getgabs/calls')
            .invokeMethod('markCallAccepted');
        debugPrint('✅ Native notified: markCallAccepted');
      } catch (e) {
        debugPrint('⚠️ markCallAccepted channel error: $e');
      }
    }

    await _createPeerConnection();

    localStream = await webrtc.navigator.mediaDevices.getUserMedia({
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true
      },
      'video': false,
    }).timeout(const Duration(seconds: 10));

    for (var track in localStream!.getTracks()) {
      peerConnection!.addTrack(track, localStream!);
    }

    await peerConnection!
        .setRemoteDescription(RTCSessionDescription(safeSdp, 'offer'));

    // Drain remote ICE candidates that arrived before _createPeerConnection ran.
    // These were buffered in the 'ice_candidate' socket handler to avoid the
    // first-call failure where candidates arrived before peerConnection existed.
    if (_pendingRemoteCandidates.isNotEmpty) {
      debugPrint(
          '🚀 Draining ${_pendingRemoteCandidates.length} buffered remote ICE candidates');
      for (final c in _pendingRemoteCandidates) {
        try {
          await peerConnection!.addCandidate(c);
        } catch (e) {}
      }
      _pendingRemoteCandidates.clear();
    }

    RTCSessionDescription answer = await peerConnection!.createAnswer();
    await peerConnection!.setLocalDescription(answer);

    final response = await http
        .post(
          Uri.parse('$socketUrl/accept-whatsapp-call'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'callId': safeCallId,
            'sdpAnswer': answer.sdp,
            'api_key': businessApiKey,
            'acceptedBy': userId,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      String message = 'Failed to answer call (${response.statusCode})';
      try {
        final errorBody = jsonDecode(response.body) as Map<String, dynamic>;
        message = (errorBody['error'] ?? errorBody['message'] ?? message).toString();
      } catch (_) {}
      throw Exception(message);
    }

    // HTTP handshake done — ICE negotiation starts now. Timer and 'Connected'
    // status fire in onIceConnectionState when ICE actually reaches Connected.
    _updateStatus('Accepted');
  }

  Future<void> makeCall(String phoneNumber) async {
    print("call_make_callllllllllllllllllllllllllllllllll");
    debugPrint('🔌 Socket connected? ${socket?.connected}');

    String formattedPhone = _formatPhoneNumber(phoneNumber);
    await _requestPermissions();

    if (socket == null || !socket!.connected) {
      _updateStatus('Connecting...');
      if (socket != null && !socket!.connected) socket!.connect();

      int attempts = 0;
      while ((socket == null || !socket!.connected) && attempts < 100) {
        await Future.delayed(const Duration(milliseconds: 200));
        attempts++;
        if (attempts % 10 == 0) socket?.connect();
      }

      if (socket == null || !socket!.connected) {
        throw Exception('Unable to connect. Please check your internet.');
      }
    }

    await _createPeerConnection();

    currentPhoneNumber = formattedPhone;
    isOutgoingCall = true;
    _isCallActive = true;
    _callAccepted = true;
    _updateStatus('Calling...');
    _startCallTimeout();

    // Register this outgoing call with CallKit so it creates a CXStartCallAction
    // transaction — without this, iOS has no record of the call and it never
    // appears in the Phone app's Recents tab (unlike incoming calls, which the
    // native CallManager already reports via reportNewIncomingCall). Harmless
    // no-op on Android (see flutter_callkit_incoming's startCall doc comment).
    final outgoingCallKitId = _uuidFactory.v4();
    currentCallKitId = outgoingCallKitId;
    try {
      await FlutterCallkitIncoming.startCall(CallKitParams(
        id: outgoingCallKitId,
        nameCaller: formattedPhone,
        handle: formattedPhone,
        appName: 'GetGabs',
        type: 0,
      ));
    } catch (e) {
      debugPrint('⚠️ CallKit startCall error: $e');
    }

    // Everything past this point can throw (getUserMedia timeout, createOffer,
    // HTTP). Cancel the ringing timer on any failure so it does not leak — the
    // caller's cleanupCall() also runs, but this keeps makeCall self-contained.
    try {
      localStream = await webrtc.navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true
        },
        'video': false,
      }).timeout(const Duration(seconds: 10));

      for (var track in localStream!.getTracks()) {
        peerConnection!.addTrack(track, localStream!);
      }

      RTCSessionDescription offer = await peerConnection!.createOffer(
          {'offerToReceiveAudio': true, 'offerToReceiveVideo': false});
      await peerConnection!.setLocalDescription(offer);

      RTCSessionDescription? localDesc =
          await peerConnection!.getLocalDescription();
      String sdpOffer = localDesc?.sdp ?? offer.sdp ?? '';

      if (sdpOffer.isEmpty) {
        throw Exception('Failed to create SDP offer');
      }

      final response = await http
          .post(
            Uri.parse('$socketUrl/start-outbound-call'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'to': formattedPhone,
              'sdpOffer': sdpOffer,
              'callerId': userId,
              'adminId': adminId,
              'api_key': businessApiKey,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to start call');
      }

      final data = jsonDecode(response.body);
      currentCallId = data['callId'];
      _updateStatus('Ringing...');
    } catch (e) {
      _cancelCallTimeout();
      rethrow;
    }
  }

  Future<void> terminateCall() async {
    if (_isCleaningUp) return;
    _isCleaningUp = true;

    try {
      _cancelCallTimeout();

      final prefs = await SharedPreferences.getInstance();
      final backendCallId = currentCallId ?? prefs.getString('pending_call_id');
      final callkitId =
          currentCallKitId ?? prefs.getString('pending_callkit_id');

      if (backendCallId != null && backendCallId.isNotEmpty) {
        try {
          await http
              .post(
                Uri.parse('$socketUrl/terminate-whatsapp-call'),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(
                    {'callId': backendCallId, 'api_key': businessApiKey}),
              )
              .timeout(const Duration(seconds: 8));
        } catch (e) {
          debugPrint('❌ terminate api error: $e');
        }
      }

      if (callkitId != null && callkitId.isNotEmpty) {
        try {
          await FlutterCallkitIncoming.endCall(callkitId);
        } catch (e) {
          debugPrint('❌ endCall error: $e');
        }
        if (Platform.isIOS) {
          try {
            await const MethodChannel('com.getgabs/calls')
                .invokeMethod('endNativeCall', {'uuid': callkitId});
            debugPrint('✅ Native CallKit call ended: $callkitId');
          } catch (e) {
            debugPrint('⚠️ endNativeCall error: $e');
          }
        }
      }

      await stopRingtone();
      // Capture before cleanupCall() nulls all callbacks.
      // This covers every caller of terminateCall() (CallKit event stream,
      // ICE failed, HTTP error) — not just the onCallEndedNatively path.
      final callEndedCb = onCallEnded;
      await cleanupCall();
      callEndedCb?.call();
    } finally {
      _isCleaningUp = false;
    }
  }

  Future<void> _logCallStart() async {
    try {
      await http
          .post(
            Uri.parse('$apiBaseUrl/log-call-start'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': userId,
              'admin_id': adminId,
              'phone_number': currentPhoneNumber,
              'call_id': currentCallId,
              'call_type': isOutgoingCall ? 'outgoing' : 'incoming',
              'start_time': DateTime.now().toIso8601String(),
              'api_key': businessApiKey,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {}
  }

  Future<void> _logCallEnd() async {
    try {
      final duration = callStartTime != null
          ? DateTime.now().difference(callStartTime!).inSeconds
          : 0;
      await http
          .post(
            Uri.parse('$apiBaseUrl/log-call-end'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'user_id': userId,
              'admin_id': adminId,
              'phone_number': currentPhoneNumber,
              'call_id': currentCallId,
              'call_type': isOutgoingCall ? 'outgoing' : 'incoming',
              'end_time': DateTime.now().toIso8601String(),
              'duration_seconds': duration,
              'api_key': businessApiKey,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {}
  }

  void _updateStatus(String status) {
    callStatus = status;
    onStatusChange?.call(status);
  }

  void dispose() {
    _cancelCallTimeout();
    _clearPendingState();
    cleanupCall();
    if (!isGlobalListener) {
      socket?.disconnect();
      socket?.dispose();
    }
  }
}

// ============================================
// INCOMING CALL CARD — IN-APP POPUP
// ============================================
class IncomingCallCard extends StatelessWidget {
  final String callerName;
  final String callerNumber;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const IncomingCallCard({
    super.key,
    required this.callerName,
    required this.callerNumber,
    required this.onAccept,
    required this.onDecline,
  });

  String _getDisplayName() {
    if (callerName.isNotEmpty &&
        !RegExp(r'^[\d\s\+\-\(\)]+$').hasMatch(callerName)) {
      return callerName;
    }
    return callerNumber;
  }

  String _getInitials(String name) {
    if (name.isNotEmpty && !RegExp(r'^[\d\s\+\-\(\)]+$').hasMatch(name)) {
      final words = name.trim().split(RegExp(r'\s+'));
      if (words.length >= 2)
        return '${words[0][0]}${words[1][0]}'.toUpperCase();
      if (words.isNotEmpty && words[0].isNotEmpty)
        return words[0][0].toUpperCase();
    }
    return 'G';
  }

  String _formatPhoneDisplay(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.startsWith('+91') && cleaned.length == 13) {
      return '+91 ${cleaned.substring(3, 8)} ${cleaned.substring(8)}';
    } else if (cleaned.startsWith('91') && cleaned.length == 12) {
      return '+91 ${cleaned.substring(2, 7)} ${cleaned.substring(7)}';
    }
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _getDisplayName();
    final initials = _getInitials(callerName);
    final formattedNumber = _formatPhoneDisplay(callerNumber);

    // ✅ Per-flavor branding for the incoming-call header — was hardcoded to
    // GetGabs green/"G"/"GetGabs Audio Calling" for all three apps.
    final Color brandColor = AppTheme.currentFlavor == 'messagedly'
        ? const Color(0xff4242D4)
        : AppTheme.currentFlavor == 'scalewiz'
            ? const Color(0xff0E7C74)
            : const Color(0xFF034737);
    final String brandLetter = AppTheme.currentFlavor == 'messagedly'
        ? 'M'
        : AppTheme.currentFlavor == 'scalewiz'
            ? 'S'
            : 'G';
    final String brandLabel = AppTheme.currentFlavor == 'messagedly'
        ? 'Messagedly Audio Calling'
        : AppTheme.currentFlavor == 'scalewiz'
            ? 'Scalewiz Audio Calling'
            : 'GetGabs Audio Calling';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 24,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: brandColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6)),
                  child: Center(
                    child: Text(brandLetter,
                        style: TextStyle(
                            color: brandColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Text(brandLabel,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                      color: Color(0xFF034737), shape: BoxShape.circle),
                  child: Center(
                    child: Text(initials,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName,
                          style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 16,
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(formattedNumber,
                          style: const TextStyle(
                              color: Color(0xFF888888), fontSize: 13)),
                      const SizedBox(height: 2),
                      const Text('Incoming voice call',
                          style: TextStyle(
                              color: Color(0xFF034737),
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: onDecline,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEEEE),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFFE53935).withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.call_end,
                        color: Color(0xFFE53935), size: 22),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: onAccept,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                        color: Color(0xFF034737), shape: BoxShape.circle),
                    child:
                        const Icon(Icons.call, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// INCOMING CALL FULL SCREEN
// ============================================
class IncomingCallScreen extends StatefulWidget {
  final WhatsAppCallingService callingService;
  final String callerName;
  final String callerNumber;
  final String? pendingSdp;
  final String? pendingCallId;

  const IncomingCallScreen({
    super.key,
    required this.callingService,
    required this.callerName,
    required this.callerNumber,
    this.pendingSdp,
    this.pendingCallId,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  String _status = 'Connecting...';
  Duration _duration = Duration.zero;
  Timer? _timer;
  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _isConnected = false;
  bool _isEnded = false;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _waveController =
        AnimationController(duration: const Duration(seconds: 2), vsync: this)
          ..repeat();

    _attachCallCallbacks();
    _syncServiceState();

    // Answer the incoming call once the UI is ready and the app is
    // in the foreground on iOS. If the app is still inactive after the first
    // frame, didChangeAppLifecycleState will retry when resumed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryAnswerIfNeeded();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _tryAnswerIfNeeded();
    }
  }

  void _attachCallCallbacks() {
    widget.callingService.onStatusChange = (s) {
      if (!mounted || _isEnded) return;
      final statusLower = s.toLowerCase();
      if (statusLower.contains('connected')) {
        setState(() {
          _isConnected = true;
          _status = 'Connected';
        });
        _startTimer();
      } else if (statusLower.contains('accepted')) {
        setState(() {});
      } else if (statusLower.contains('ended') ||
          statusLower.contains('failed') ||
          statusLower.contains('terminated') ||
          statusLower.contains('declined')) {
        _handleCallEnded(s);
      } else {
        setState(() => _status = s);
      }
    };

    widget.callingService.onCallEnded = () => _handleCallEnded('Call ended');
    widget.callingService.onError = (e) {
      if (mounted && !_isEnded) _handleCallEnded(e);
    };
  }

  void _syncServiceState() {
    if (!widget.callingService.callAccepted) return;

    final alreadyConnected = widget.callingService.callStartTime != null ||
        widget.callingService.callStatus.toLowerCase().contains('connected');

    if (alreadyConnected) {
      setState(() {
        _isConnected = true;
        _status = 'Connected';
      });
      _startTimer();
    } else {
      setState(() {
        _status = widget.callingService.callStatus.isNotEmpty
            ? widget.callingService.callStatus
            : 'Connecting...';
      });
    }
  }

  void _tryAnswerIfNeeded() {
    if (widget.callingService.callAccepted) return;
    if (Platform.isIOS &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    _answerCall();
  }

  String _getInitials(String name, String number) {
    if (name.isNotEmpty && !RegExp(r'^[\d\s\+\-\(\)]+$').hasMatch(name)) {
      final words = name.trim().split(RegExp(r'\s+'));
      if (words.length >= 2)
        return '${words[0][0]}${words[1][0]}'.toUpperCase();
      if (words.isNotEmpty && words[0].isNotEmpty)
        return words[0][0].toUpperCase();
    }
    String cleaned = number.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length >= 2) return cleaned.substring(cleaned.length - 2);
    return '?';
  }

  String _getDisplayName() {
    if (widget.callerName.isNotEmpty &&
        !RegExp(r'^[\d\s\+\-\(\)]+$').hasMatch(widget.callerName)) {
      return widget.callerName;
    }
    return _formatPhoneDisplay(widget.callerNumber);
  }

  String _formatPhoneDisplay(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.startsWith('+91') && cleaned.length == 13)
      return '+91 ${cleaned.substring(3, 8)} ${cleaned.substring(8)}';
    if (cleaned.startsWith('91') && cleaned.length == 12)
      return '+91 ${cleaned.substring(2, 7)} ${cleaned.substring(7)}';
    return phone;
  }

  bool _shouldShowPhoneNumber() {
    final displayName = _getDisplayName();
    return displayName != widget.callerNumber &&
        displayName != _formatPhoneDisplay(widget.callerNumber) &&
        widget.callerNumber.isNotEmpty;
  }

  void _handleCallEnded(String reason) {
    if (_isEnded) return;
    _timer?.cancel();
    if (mounted) {
      setState(() {
        _status = reason;
        _isEnded = true;
        _isConnected = false;
      });
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) Get.back();
      });
    }
  }

  Future<void> _answerCall() async {
    try {
      if (widget.pendingSdp == null || widget.pendingCallId == null) {
        _handleCallEnded('Call expired');
        return;
      }
      await widget.callingService.answerCall();
    } catch (e) {
      // cleanupCall() resets _callAccepted/_isCallActive so the next
      // incoming call is not permanently blocked by stale true-flags.
      await widget.callingService.cleanupCall();
      _handleCallEnded('Failed to connect');
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_isEnded)
        setState(() => _duration += const Duration(seconds: 1));
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    if (d.inHours > 0)
      return '${twoDigits(d.inHours)}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}';
    return '${twoDigits(d.inMinutes)}:${twoDigits(d.inSeconds.remainder(60))}';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WhatsAppCallingConfig.notifyCallScreenClosed();
    _waveController.dispose();
    _timer?.cancel();
    widget.callingService.onStatusChange = null;
    widget.callingService.onCallEnded = null;
    widget.callingService.onError = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _getDisplayName();
    final initials = _getInitials(widget.callerName, widget.callerNumber);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF5F5F5), Colors.white, Color(0xFFFAFAFA)],
            stops: [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(children: [
                  IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: Color(0xFF1F2C34)),
                      onPressed: () {
                        widget.callingService.terminateCall();
                        _handleCallEnded('Call ended');
                      }),
                  const Spacer(),
                  if (_isConnected && !_isEnded)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00A884).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                                color: Color(0xFF00A884),
                                shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        const Text('Encrypted',
                            style: TextStyle(
                                color: Color(0xFF00A884),
                                fontSize: 11,
                                fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ]),
              ),
              const Spacer(),
              Stack(alignment: Alignment.center, children: [
                if (!_isConnected && !_isEnded)
                  AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, child) => CustomPaint(
                      size: const Size(200, 200),
                      painter: _WavePainter(
                          animationValue: _waveController.value,
                          color: const Color(0xFF00A884)),
                    ),
                  ),
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        _isEnded ? Colors.grey[400] : const Color(0xFF00A884),
                    boxShadow: _isEnded
                        ? null
                        : [
                            BoxShadow(
                                color:
                                    const Color(0xFF00A884).withOpacity(0.25),
                                blurRadius: 25,
                                spreadRadius: 3)
                          ],
                  ),
                  child: Center(
                    child: Text(initials,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(displayName,
                    style: const TextStyle(
                        color: Color(0xFF1F2C34),
                        fontSize: 26,
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(height: 8),
              if (_shouldShowPhoneNumber())
                Text(_formatPhoneDisplay(widget.callerNumber),
                    style: TextStyle(color: Colors.grey[600], fontSize: 15)),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (!_isConnected && !_isEnded)
                  Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(right: 8),
                      child: const CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF00A884))),
                Text(
                  _isConnected && !_isEnded
                      ? _formatDuration(_duration)
                      : _status,
                  style: TextStyle(
                    color: _isEnded
                        ? Colors.redAccent
                        : _isConnected
                            ? const Color(0xFF00A884)
                            : Colors.grey[600],
                    fontSize: _isConnected ? 20 : 15,
                    fontWeight:
                        _isConnected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ]),
              const Spacer(),
              if (!_isEnded)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildControlButton(
                            _isSpeaker
                                ? Icons.volume_up
                                : Icons.volume_up_outlined,
                            'Speaker',
                            _isSpeaker,
                            () => setState(() => _isSpeaker = !_isSpeaker)),
                        _buildControlButton(
                            Icons.videocam_off_outlined, 'Video', false, () {},
                            isDisabled: true),
                        _buildControlButton(
                            _isMuted ? Icons.mic_off : Icons.mic_none,
                            'Mute',
                            _isMuted, () {
                          setState(() => _isMuted = !_isMuted);
                          widget.callingService.localStream
                              ?.getAudioTracks()
                              .forEach((t) => t.enabled = !_isMuted);
                        }),
                      ]),
                ),
              SizedBox(height: _isEnded ? 20 : 30),
              GestureDetector(
                onTap: _isEnded
                    ? () => Get.back()
                    : () {
                        widget.callingService.terminateCall();
                        _handleCallEnded('Call ended');
                      },
                child: Container(
                  width: 65,
                  height: 65,
                  decoration: BoxDecoration(
                    color:
                        _isEnded ? Colors.grey[400] : const Color(0xFFEA4335),
                    shape: BoxShape.circle,
                    boxShadow: _isEnded
                        ? null
                        : [
                            BoxShadow(
                                color:
                                    const Color(0xFFEA4335).withOpacity(0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4))
                          ],
                  ),
                  child: Icon(_isEnded ? Icons.close : Icons.call_end,
                      color: Colors.white, size: 28),
                ),
              ),
              const SizedBox(height: 8),
              if (_isEnded)
                Text('Close',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton(
      IconData icon, String label, bool isActive, VoidCallback onTap,
      {bool isDisabled = false}) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF00A884)
                : isDisabled
                    ? Colors.grey[200]
                    : Colors.grey[100],
            shape: BoxShape.circle,
            border: Border.all(
                color: isActive ? const Color(0xFF00A884) : Colors.grey[300]!,
                width: 1),
          ),
          child: Icon(icon,
              color: isActive
                  ? Colors.white
                  : isDisabled
                      ? Colors.grey[400]
                      : const Color(0xFF1F2C34),
              size: 22),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
                color: isDisabled ? Colors.grey[400] : Colors.grey[700],
                fontSize: 11,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ============================================
// WAVE PAINTER
// ============================================
class _WavePainter extends CustomPainter {
  final double animationValue;
  final Color color;
  _WavePainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < 3; i++) {
      double progress = (animationValue + i * 0.33) % 1.0;
      double radius = 55 + (progress * 45);
      double opacity = (1 - progress) * 0.4;
      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}

// ============================================
// GLOBAL CALL LISTENER SERVICE
// ============================================
class GlobalCallListenerService {
  static GlobalCallListenerService? _instance;

  static GlobalCallListenerService get instance {
    _instance ??= GlobalCallListenerService._();
    return _instance!;
  }

  GlobalCallListenerService._();

  WhatsAppCallingService? _service;
  bool _isInitialized = false;
  bool _isInitializing = false;
  Map<String, dynamic>? pendingCall;
  StreamSubscription? _callkitSubscription;

  WhatsAppCallingService? get service => _service;

  void openCallScreen({
    required WhatsAppCallingService service,
    required String callerName,
    required String callerNumber,
    required String sdp,
    required String callId,
  }) {
    if (WhatsAppCallingConfig.isCallScreenOpen) {
      debugPrint('⚠️ Call screen already opened');
      return;
    }
    WhatsAppCallingConfig.notifyCallScreenOpened();
    Get.to(
      () => IncomingCallScreen(
        callingService: service,
        callerName: callerName,
        callerNumber: callerNumber,
        pendingSdp: sdp,
        pendingCallId: callId,
      ),
      transition: Transition.fadeIn,
    )?.then((_) => WhatsAppCallingConfig.notifyCallScreenClosed());
  }

  // #changedWithJClaude — Bug 5: guard against service teardown while a call is pending/active.
  // Previously any call to initialize() with a disconnected socket would dispose the service
  // and lose the SDP that was already set via setPendingCall(). Now we reconnect instead.
  Future<void> initialize({
    required int userId,
    required int adminId,
    required String businessApiKey,
    int? socketUserId,
  }) async {
    // Guard against concurrent calls (e.g. onReady + onIncomingVoipCall racing).
    if (_isInitializing) {
      debugPrint('⏭️ GlobalListener already initializing — skipping duplicate call');
      return;
    }

    // If already set up and a pending/active call is in progress, never tear
    // down — just reconnect the socket if it dropped. Tearing down here would
    // destroy the pending SDP that was stored before the user answered.
    if (_isInitialized && _service != null) {
      if (_service!.hasActivePendingCall || _service!.isCallActive) {
        if (_service!.socket?.connected != true) {
          _service!.socket?.connect();
          debugPrint('🔄 GlobalListener: socket reconnected for active call');
        } else {
          debugPrint(
              '✅ GlobalListener already active with pending call — skipping reinit');
        }
        return;
      }
      if (_service!.socket?.connected == true) {
        debugPrint('✅ GlobalListener already active');
        return;
      }
    }

    _isInitializing = true;
    debugPrint('🌐 GlobalListener initializing...');

    try {
      if (_service != null) {
        _service!.onStatusChange = null;
        _service!.onCallEnded = null;
        _service!.onError = null;
        _service!.onIncomingCall = null;
        await _service!.cleanupCall();
        _service!.socket?.disconnect();
        _service!.socket?.dispose();
        _service = null;
      }

      await _callkitSubscription?.cancel();
      _isInitialized = false;

      _service = WhatsAppCallingService(
        userId: userId,
        adminId: adminId,
        userRole: 'agent',
        businessApiKey: businessApiKey,
        socketUserId: socketUserId,
      );
      _service!.isGlobalListener = true;
      await _service!.initialize();

      // Mark initialized BEFORE the iOS-only early return so Android callers
      // see isInitialized=true and the guard at line 1927 prevents unnecessary
      // service teardowns on subsequent initialize() calls.
      _isInitialized = true;

      // ============================================
      // CALLKIT EVENT LISTENER
      // ============================================
      // On Android, setupCallKitEvents() in api_end_points.dart already handles
      // all FlutterCallkitIncoming events. Registering a second listener here
      // would cause CallEventActionCallAccept to be processed twice concurrently,
      // creating a race where the first handler may clear SharedPreferences before
      // the second reads them, resulting in empty callId/sdp for setPendingCall().
      if (!Platform.isIOS) return;

      _callkitSubscription = FlutterCallkitIncoming.onEvent.listen((event) async {
        debugPrint('📞 CallKit EVENT: $event');

        // ✅ v3.0.0 — sealed class pattern (Event enum removed)
        if (event is CallEventActionCallAccept) {
          debugPrint('📞 ACCEPT CLICKED');

          final prefs = await SharedPreferences.getInstance();
          final callId = prefs.getString('pending_call_id');
          final sessionString = prefs.getString('pending_call_session');
          final callerName = prefs.getString('pending_caller_name') ?? 'Unknown';
          final callerNumber = prefs.getString('pending_caller_number') ?? '';

          if (callId == null || sessionString == null) return;

          final session = jsonDecode(sessionString);

          _service?.setPendingCall(callId: callId, sdp: session['sdp']);

          if (_service?.socket?.connected != true) {
            _service?.socket?.connect();
            await Future.delayed(const Duration(seconds: 2));
          }

          // ✅ FOREGROUND
          if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
            debugPrint('🟢 FOREGROUND FLOW');
            if (WhatsAppCallingConfig.isCallScreenOpen) {
              debugPrint('⚠️ Screen already open');
              return;
            }
            openCallScreen(
              service: _service!,
              callerName: callerName,
              callerNumber: callerNumber,
              sdp: session['sdp'],
              callId: callId,
            );
          }

          // #changedWithJClaude — Bug 4: removed answerCall() + _waitForSocketConnected +
          // _quickAcceptToServer from the background path. getUserMedia() fails silently in
          // iOS background (no active audio session), and the socket wait (up to 12 s) races
          // the server timeout. Now we only store pending nav; the full WebRTC handshake runs
          // in IncomingCallScreen.initState() once CallKit has activated the audio session.
          // Also deleted the now-unused _waitForSocketConnected and _quickAcceptToServer helpers.
          // BACKGROUND / KILLED
          else {
            debugPrint('🔴 BACKGROUND FLOW — deferring WebRTC to foreground');

            final bgUserId = await WhatsAppCallingConfig.getUserId();
            final bgAdminId = await WhatsAppCallingConfig.getAdminId();
            final bgApiKey = await WhatsAppCallingConfig.getBusinessApiKey();
            final avatar =
                'https://ui-avatars.com/api/?name=${Uri.encodeComponent(callerName)}&background=075E54&color=fff&size=200&rounded=true';

            // Store nav so AppLifecycleObserver.resumed opens the call screen.
            // Do NOT call answerCall() here — iOS audio session is not active in
            // background, getUserMedia() fails silently, and the SDP exchange
            // would race against the server timeout before the UI even opens.
            // The full WebRTC handshake runs in IncomingCallScreen.initState()
            // once the app foregrounds and the audio session is activated by CallKit.
            WhatsAppCallingConfig.storePendingNavigation({
              'userId': bgUserId,
              'adminId': bgAdminId,
              'apiKey': bgApiKey,
              'callerNumber': callerNumber,
              'callerName': callerName,
              'avatar': avatar,
            });
            debugPrint('✅ Pending navigation stored — will open on foreground');
          }
        } else if (event is CallEventActionCallTimeout) {
          debugPrint('📞 Call Timeout');
          await _service?.terminateCall();
        } else if (event is CallEventActionCallEnded) {
          debugPrint('📞 Call Ended');
          await _service?.terminateCall();
        } else if (event is CallEventActionCallToggleAudioSession) {
          debugPrint('📞 Audio session toggled');
        } else {
          debugPrint('📞 Unhandled CallKit event: $event');
        }
      }, onError: (e, stack) {
        // flutter_callkit_incoming throws FormatException for ACTION_CALL_TOGGLE_AUDIO_SESSION
        // when iOS fires it without an id — swallow the error so the subscription stays alive.
        debugPrint('⚠️ CallKit stream error (ignored): $e');
      }, cancelOnError: false);

      _isInitialized = true;
      debugPrint('✅ GlobalCallListenerService initialized');
    } finally {
      _isInitializing = false;
    }
  }

  void dispose() {
    _callkitSubscription?.cancel();
    _service?.dispose();
    _service = null;
    _isInitialized = false;
  }

  bool get isInitialized => _isInitialized;
}
