// File: lib/domain/services/whatsapp_calling_service.dart
// ✅ UNIFIED FILE — Works for both Android & iOS

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:flutter_webrtc/flutter_webrtc.dart' hide navigator;
import 'package:get/get.dart';
import 'package:getgabs/domain/end_points/api_end_points.dart';
import 'package:getgabs/main.dart';
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
  });

  String? get pendingSdp => _pendingSdp;
  String? get pendingCallId => _pendingCallId;
  bool get hasActivePendingCall => _hasActivePendingCall;

  void _clearPendingState() {
    _pendingSdp = null;
    _pendingCallId = null;
    _hasActivePendingCall = false;
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
          .setAuth({'userId': userId, 'role': userRole})
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

      if (_callAccepted) {
        debugPrint(
            '⚠️ Call already accepted — ignoring duplicate socket event');
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
      callStartTime = DateTime.now();
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
      await _logCallStart();
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
      if (peerConnection != null && data['candidate'] != null) {
        try {
          await peerConnection!.addCandidate(RTCIceCandidate(
            data['candidate']['candidate'],
            data['candidate']['sdpMid'],
            data['candidate']['sdpMLineIndex'],
          ));
        } catch (e) {}
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
      // #changedWithJClaude — flush any ICE candidates that were generated while the
      // socket was still reconnecting after a background→foreground transition.
      if (_bufferedIceCandidates.isNotEmpty) {
        debugPrint(
            '🚀 Flushing ${_bufferedIceCandidates.length} buffered ICE candidates');
        for (final payload in _bufferedIceCandidates) {
          socket!.emit('ice_candidate', payload);
        }
        _bufferedIceCandidates.clear();
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
      await prefs.setString(
        'pending_call_session',
        jsonEncode({'sdp': sdpOffer, 'sdp_type': 'offer'}),
      );

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
        appName: 'GetGabs',
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

  Future<void> _handleCallEnded(String reason) async {
    if (_isCleaningUp) return;
    _isCleaningUp = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final callkitId =
          currentCallKitId ?? prefs.getString('pending_callkit_id');

      if (callkitId != null && callkitId.isNotEmpty) {
        debugPrint('🧹 Cleaning up CallKit UUID: $callkitId');
        await FlutterCallkitIncoming.endCall(callkitId);
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
    await cleanupCall();
    onCallEnded?.call();
    _isCleaningUp = false;
  }

  Future<void> cleanupCall() async {
    debugPrint('🧹 Starting Full Cleanup...');
    _isCallActive = false;
    _callKitShowing = false;
    _cancelCallTimeout();

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

    peerConnection = null;
    localStream = null;
    remoteStream = null;
    currentCallKitId = null;
    currentCallId = null;
    incomingSdp = null;
    callStartTime = null;
    currentPhoneNumber = null;
    currentCallerName = null;
    _callAccepted = false;
    _bufferedIceCandidates.clear(); // #changedWithJClaude

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
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected) {
        _cancelCallTimeout();
        _updateStatus('Accepted');
        _isCallActive = true;
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _cancelCallTimeout();
        onError?.call('Connection failed');
        _handleCallEnded('Connection failed');
      }
    };
  }

  Future<void> answerCall() async {
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

    String safeSdp = _pendingSdp!;
    String safeCallId = _pendingCallId!;

    incomingSdp = safeSdp;
    currentCallId = safeCallId;
    _isCallActive = true;
    _callAccepted = true;

    await _requestPermissions();
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
      throw Exception('Failed to answer: ${response.statusCode}');
    }

    _updateStatus('Connected');
    callStartTime = DateTime.now();
    await _logCallStart();
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

    await Future.delayed(const Duration(seconds: 2));

    RTCSessionDescription? localDesc =
        await peerConnection!.getLocalDescription();
    String sdpOffer = localDesc?.sdp ?? offer.sdp ?? '';

    if (sdpOffer.isEmpty) {
      _cancelCallTimeout();
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
      _cancelCallTimeout();
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Failed to start call');
    }

    final data = jsonDecode(response.body);
    currentCallId = data['callId'];
    _updateStatus('Ringing...');
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
          await http.post(
            Uri.parse('$socketUrl/terminate-whatsapp-call'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(
                {'callId': backendCallId, 'api_key': businessApiKey}),
          );
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
      }

      await stopRingtone();
      await cleanupCall();
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
            decoration: const BoxDecoration(
              color: Color(0xFF034737),
              borderRadius: BorderRadius.only(
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
                  child: const Center(
                    child: Text('G',
                        style: TextStyle(
                            color: Color(0xFF034737),
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('GetGabs Audio Calling',
                    style: TextStyle(
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
    with TickerProviderStateMixin {
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
    _waveController =
        AnimationController(duration: const Duration(seconds: 2), vsync: this)
          ..repeat();

    // ✅ iOS: postFrameCallback use karo + foreground check
    // ✅ Android: direct answerCall
    if (Platform.isIOS) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (isAppInForeground && !widget.callingService.callAccepted) {
          await _answerCall();
        }
      });
    } else {
      _answerCall();
    }
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

    try {
      if (widget.pendingSdp == null || widget.pendingCallId == null) {
        _handleCallEnded('Call expired');
        return;
      }
      await widget.callingService.answerCall();
    } catch (e) {
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
                        Get.back();
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
                    : () => widget.callingService.terminateCall(),
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
  bool _callScreenOpen = false;
  bool _isInitialized = false;
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
    if (_callScreenOpen) {
      debugPrint('⚠️ Call screen already opened');
      return;
    }
    _callScreenOpen = true;
    Get.to(
      () => IncomingCallScreen(
        callingService: service,
        callerName: callerName,
        callerNumber: callerNumber,
        pendingSdp: sdp,
        pendingCallId: callId,
      ),
      transition: Transition.fadeIn,
    )?.then((_) => _callScreenOpen = false);
  }

  // #changedWithJClaude — Bug 5: guard against service teardown while a call is pending/active.
  // Previously any call to initialize() with a disconnected socket would dispose the service
  // and lose the SDP that was already set via setPendingCall(). Now we reconnect instead.
  Future<void> initialize({
    required int userId,
    required int adminId,
    required String businessApiKey,
  }) async {
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

    debugPrint('🌐 GlobalListener initializing...');

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
    );
    _service!.isGlobalListener = true;
    await _service!.initialize();

    // ============================================
    // CALLKIT EVENT LISTENER
    // ============================================
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
        if (isAppInForeground) {
          debugPrint('🟢 FOREGROUND FLOW');
          if (_callScreenOpen) {
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
  }

  void dispose() {
    _callkitSubscription?.cancel();
    _service?.dispose();
    _service = null;
    _isInitialized = false;
  }

  bool get isInitialized => _isInitialized;
}
