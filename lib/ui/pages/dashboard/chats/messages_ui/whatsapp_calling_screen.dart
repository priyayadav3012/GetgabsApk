// File: lib/ui/pages/dashboard/chats/messages_ui/whatsapp_calling_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:getgabs/domain/end_points/api_end_points.dart';
import 'package:getgabs/domain/services/whtasapp_calling_service.dart';
import 'package:getgabs/ui/themes/themes.dart';

class WhatsAppCallingScreen extends StatefulWidget {
  final int userId;
  final int adminId;
  final String businessApiKey;
  final String initialPhoneNumber;
  final String contactName;
  final String? contactAvatar;
  final bool isIncoming;

  const WhatsAppCallingScreen({
    super.key,
    required this.userId,
    required this.adminId,
    required this.businessApiKey,
    required this.initialPhoneNumber,
    this.contactName = '',
    this.contactAvatar,
    this.isIncoming = false,
  });

  @override
  State<WhatsAppCallingScreen> createState() => _WhatsAppCallingScreenState();
}

class _WhatsAppCallingScreenState extends State<WhatsAppCallingScreen>
    with TickerProviderStateMixin {
  WhatsAppCallingService? _callingService;

  bool get isMessagedly => (AppTheme.unreadMessagesColor.value != 0xFF25D366 &&
      AppTheme.unreadMessagesColor != Colors.green);

  // 🎨 DYNAMIC COLORS DEFINITION
  Color get primaryColor => isMessagedly ? const Color(0xff4242D4) : const Color(0xFF00A884); // Messagedly par absolute Blue 🔵 / GetGabs par Green 🟢
  Color get darkBgColor => isMessagedly ? const Color(0xff1A1A5E) : const Color(0xFF034737);   // Waves aur status ke liye dark variant
  
  String _status = 'Connecting...';
  Duration _duration = Duration.zero;
  Timer? _timer;
  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _isConnected = false;
  bool _isEnded = false;
  bool _isExternalService = false;

  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController =
        AnimationController(duration: const Duration(seconds: 2), vsync: this)
          ..repeat();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    _initCall();
  }

  Future<void> _initCall() async {
    // ✅ Step 1: Global service reuse karo agar socket connected ho
    if (GlobalCallListenerService.instance.isInitialized &&
        GlobalCallListenerService.instance.service != null &&
        GlobalCallListenerService.instance.service!.socket?.connected == true) {
      _callingService = GlobalCallListenerService.instance.service;
      _isExternalService = true;
      debugPrint('✅ Reusing global service socket');
    } else {
      // ✅ Step 2: Global listener reinitialize karo
      debugPrint('⚠️ Global service not available, reinitializing...');
      await WhatsAppCallingConfig.initializeCallListener();

      if (GlobalCallListenerService.instance.isInitialized &&
          GlobalCallListenerService.instance.service != null) {
        _callingService = GlobalCallListenerService.instance.service;
        _isExternalService = true;
        debugPrint('✅ Reusing reinitialized global service');
      } else {
        // ✅ Step 3: Last resort — naya service banao
        _callingService = WhatsAppCallingService(
          userId: widget.userId,
          adminId: widget.adminId,
          userRole: 'agent',
          businessApiKey: widget.businessApiKey,
        );
        _isExternalService = false;
        await _callingService!.initialize();
        debugPrint('text✅ Created new service');
      }
    }

    // ✅ Callbacks setup karo
    _callingService!.onStatusChange = (s) {
      if (!mounted || _isEnded) return;
      final statusLower = s.toLowerCase();
      debugPrint('📞 Status changed: $s');

      if (statusLower.contains('connected')) {
        setState(() {
          _isConnected = true;
          _status = 'Connected';
        });
        _startTimer();
      } else if (statusLower.contains('accepted')) {
        setState(() => _status = 'Ringing...');
      } else if (statusLower.contains('ringing') ||
          statusLower.contains('calling')) {
        setState(() {
          _isConnected = false;
          _status = 'Connecting...';
        });
      } else if (statusLower.contains('no answer') ||
          statusLower.contains('unavailable')) {
        _handleCallEnded('No answer');
      } else if (statusLower.contains('busy')) {
        _handleCallEnded('User is busy');
      } else if (statusLower.contains('declined') ||
          statusLower.contains('rejected')) {
        _handleCallEnded('Call declined');
      } else if (statusLower.contains('ended') ||
          statusLower.contains('failed') ||
          statusLower.contains('terminated')) {
        _handleCallEnded(s);
      } else {
        setState(() => _status = s);
      }
    };

    _callingService!.onCallEnded = () {
      debugPrint('📴 onCallEnded triggered');
      _handleCallEnded('Call ended');
    };

    _callingService!.onError = (e) {
      debugPrint('❌ Call error: $e');
      if (mounted && !_isEnded) _handleCallEnded(e);
    };

    // ✅ Step 4: Incoming ya Outgoing
    if (widget.isIncoming) {
      setState(() => _status = 'Connecting...');
      try {
        await Future.delayed(const Duration(milliseconds: 300));

        if (_callingService!.socket?.connected != true) {
          debugPrint('⏳ Waiting for socket connection...');
          int wait = 0;
          while (_callingService!.socket?.connected != true && wait < 30) {
            await Future.delayed(const Duration(milliseconds: 200));
            wait++;
          }
        }

        if (_callingService!.hasActivePendingCall) {
          debugPrint('✅ hasActivePendingCall = true, calling answerCall()...');
          await _callingService!.answerCall();
        } else {
          debugPrint('❌ No pending call found — call may have expired');
          _handleCallEnded('Call expired');
        }
      } catch (e) {
        debugPrint('❌ answerCall error: $e');
        _handleCallEnded(e.toString().replaceAll('Exception: ', ''));
      }
    } else if (widget.initialPhoneNumber.isNotEmpty) {
      setState(() => _status = 'Calling...');
      try {
        if (_callingService!.socket?.connected != true) {
          debugPrint('⏳ Waiting for socket before makeCall...');
          int wait = 0;
          while (_callingService!.socket?.connected != true && wait < 30) {
            await Future.delayed(const Duration(milliseconds: 200));
            wait++;
          }
        }
        await _callingService!.makeCall(widget.initialPhoneNumber);
      } catch (e) {
        _handleCallEnded(e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  void _handleCallEnded(String reason) {
    if (_isEnded) return;

    debugPrint('📴 Handling call end: $reason');
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

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_isEnded) {
        setState(() => _duration += const Duration(seconds: 1));
      }
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${twoDigits(d.inHours)}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}';
    }
    return '${twoDigits(d.inMinutes)}:${twoDigits(d.inSeconds.remainder(60))}';
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _callingService?.localStream
        ?.getAudioTracks()
        .forEach((t) => t.enabled = !_isMuted);
    HapticFeedback.lightImpact();
  }

  void _toggleSpeaker() {
    setState(() => _isSpeaker = !_isSpeaker);
    HapticFeedback.lightImpact();
  }

  void _endCall() {
  HapticFeedback.mediumImpact();
  _handleCallEnded('Call ended');   // 👈 UI turant update + timer cancel
  _callingService?.terminateCall(); // 👈 backend/socket cleanup async
}

  String _getInitials(String name, String number) {
    if (name.isNotEmpty && !_isOnlyNumbers(name)) {
      final words = name.trim().split(RegExp(r'\s+'));
      if (words.length >= 2 &&
          words[0].isNotEmpty &&
          words[1].isNotEmpty) {
        return '${words[0][0]}${words[1][0]}'.toUpperCase();
      } else if (words.isNotEmpty && words[0].isNotEmpty) {
        return words[0][0].toUpperCase();
      }
    }
    String cleaned = number.replaceAll(RegExp(r'[^\d]'), '');
    if (cleaned.length >= 2) {
      return cleaned.substring(cleaned.length - 2);
    } else if (cleaned.isNotEmpty) {
      return cleaned;
    }
    return '?';
  }

  bool _isOnlyNumbers(String text) {
    return RegExp(r'^[\d\s\+\-\(\)]+$').hasMatch(text);
  }

  String _getDisplayName() {
    if (widget.contactName.isNotEmpty && !_isOnlyNumbers(widget.contactName)) {
      return widget.contactName;
    }
    return _formatPhoneDisplay(widget.initialPhoneNumber);
  }

  String _formatPhoneDisplay(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.startsWith('+91') && cleaned.length == 13) {
      return '+91 ${cleaned.substring(3, 99)} ${cleaned.substring(99)}';
    } else if (cleaned.startsWith('91') && cleaned.length == 12) {
      return '+91 ${cleaned.substring(2, 7)} ${cleaned.substring(7)}';
    }
    return phone;
  }

  bool _shouldShowPhoneNumber() {
    final displayName = _getDisplayName();
    final formattedPhone = _formatPhoneDisplay(widget.initialPhoneNumber);
    return displayName != formattedPhone && widget.initialPhoneNumber.isNotEmpty;
  }

  @override
  void dispose() {
    _waveController.dispose();
    _timer?.cancel();

    if (_isExternalService) {
      _callingService?.onStatusChange = null;
      _callingService?.onCallEnded = null;
      _callingService?.onError = null;
    } else {
      _callingService?.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _getDisplayName();
    final initials = _getInitials(widget.contactName, widget.initialPhoneNumber);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF5F5F5),
              Colors.white,
              Color(0xFFFAFAFA),
            ],
            stops: [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2C34)),
                      onPressed: () {
                        _callingService?.terminateCall();
                        Get.back();
                      },
                    ),
                    const Spacer(),
                    if (_isConnected && !_isEnded)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: darkBgColor.withOpacity(0.1), // ✅ Dynamic Encrypted Pill Background
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                  color: darkBgColor, // ✅ Dynamic Small Dot Color
                                  shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 4),
                            Text('Encrypted',
                                style: TextStyle(
                                    color: primaryColor, // ✅ Dynamic Encrypted Text
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    const Spacer(),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              const Spacer(),

              // 🔵 AVATAR WITH DYNAMIC WAVES
              Stack(
                alignment: Alignment.center,
                children: [
                  if (!_isConnected && !_isEnded)
                    AnimatedBuilder(
                      animation: _waveController,
                      builder: (context, child) => CustomPaint(
                        size: const Size(200, 200),
                        painter: _WavePainter(
                          animationValue: _waveController.value,
                          color: darkBgColor, // ✅ Dynamic wave color (Blue / Dark Green)
                        ),
                      ),
                    ),
                  
                  // Main Avatar Container
                  Container(
                    width: 114,
                    height: 114,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isEnded
                          ? Colors.grey[300]
                          : primaryColor.withOpacity(0.2), // ✅ External Ring Blend
                    ),
                    child: Center(
                      child: Container(
                        width: 106,
                        height: 106,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isEnded ? Colors.grey[400] : primaryColor, // ✅ Dynamic Fallback Color
                          boxShadow: _isEnded
                              ? null
                              : [
                                  BoxShadow(
                                    color: primaryColor.withOpacity(0.3), // ✅ Dynamic Shadow Glow
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                        ),
                        child: ClipOval(
                          child: widget.contactAvatar != null && widget.contactAvatar!.isNotEmpty
                              ? Image.network(
                                  widget.contactAvatar!,
                                  width: 106,
                                  height: 106,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Center(
                                    child: Text(
                                      initials,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    initials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Display Name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  displayName,
                  style: const TextStyle(
                    color: Color(0xFF1F2C34),
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              const SizedBox(height: 8),

              // Phone number
              if (_shouldShowPhoneNumber())
                Text(
                  _formatPhoneDisplay(widget.initialPhoneNumber),
                  style: TextStyle(color: Colors.grey[600], fontSize: 15),
                ),

              const SizedBox(height: 16),

              // Status / Duration
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_isConnected &&
                      !_isEnded &&
                      (_status == 'Calling...' ||
                          _status == 'Ringing...' ||
                          _status == 'Connecting...'))
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(right: 8),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primaryColor, // ✅ Dynamic Small Loader Color
                      ),
                    ),
                  Text(
                    _isConnected && !_isEnded
                        ? _formatDuration(_duration)
                        : _status,
                    style: TextStyle(
                      color: _isEnded
                          ? Colors.redAccent
                          : _isConnected
                              ? primaryColor // ✅ Dynamic Connected Status Color
                              : Colors.grey[600],
                      fontSize: _isConnected ? 20 : 15,
                      fontWeight: _isConnected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Controls
              if (!_isEnded)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlButton(
                        _isSpeaker ? Icons.volume_up : Icons.volume_up_outlined,
                        'Speaker',
                        _isSpeaker,
                        _toggleSpeaker,
                      ),
                      _buildControlButton(
                        Icons.videocam_off_outlined,
                        'Video',
                        false,
                        () {},
                        isDisabled: true,
                      ),
                      _buildControlButton(
                        _isMuted ? Icons.mic_off : Icons.mic_none,
                        'Mute',
                        _isMuted,
                        _toggleMute,
                      ),
                    ],
                  ),
                ),

              SizedBox(height: _isEnded ? 20 : 30),

              // End call button
              GestureDetector(
                onTap: _isEnded ? () => Get.back() : _endCall,
                child: Container(
                  width: 65,
                  height: 65,
                  decoration: BoxDecoration(
                    color: _isEnded ? Colors.grey[400] : const Color(0xFFEA4335),
                    shape: BoxShape.circle,
                    boxShadow: _isEnded
                        ? null
                        : [
                            BoxShadow(
                              color: const Color(0xFFEA4335).withOpacity(0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Icon(
                    _isEnded ? Icons.close : Icons.call_end,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              if (_isEnded)
                Text(
                  'Close',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton(
    IconData icon,
    String label,
    bool isActive,
    VoidCallback onTap, {
    bool isDisabled = false,
  }) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isActive
                  ? primaryColor // ✅ Dynamic Active Button Background Color
                  : isDisabled
                      ? Colors.grey[200]
                      : Colors.grey[100],
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? primaryColor : Colors.grey[300]!, // ✅ Dynamic Active Button Border
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : isDisabled ? Colors.grey[400] : const Color(0xFF1F2C34),
              size: 22,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isDisabled ? Colors.grey[400] : Colors.grey[700],
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Wave Painter
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


// // File: lib/ui/pages/dashboard/chats/messages_ui/whatsapp_calling_screen.dart

// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:get/get.dart';
// import 'package:getgabs/domain/end_points/api_end_points.dart';
// import 'package:getgabs/domain/services/whtasapp_calling_service.dart';
// import 'package:getgabs/ui/themes/themes.dart';

// class WhatsAppCallingScreen extends StatefulWidget {
//   final int userId;
//   final int adminId;
//   final String businessApiKey;
//   final String initialPhoneNumber;
//   final String contactName;
//   final String? contactAvatar;
//   final bool isIncoming;

//   const WhatsAppCallingScreen({
//     super.key,
//     required this.userId,
//     required this.adminId,
//     required this.businessApiKey,
//     required this.initialPhoneNumber,
//     this.contactName = '',
//     this.contactAvatar,
//     this.isIncoming = false,
//   });

//   @override
//   State<WhatsAppCallingScreen> createState() => _WhatsAppCallingScreenState();
// }

// class _WhatsAppCallingScreenState extends State<WhatsAppCallingScreen>
//     with TickerProviderStateMixin {
//   WhatsAppCallingService? _callingService;

//   bool get isMessagedly => (AppTheme.unreadMessagesColor.value != 0xFF25D366 &&
//       AppTheme.unreadMessagesColor != Colors.green);

//   // 🎨 DYNAMIC COLORS DEFINITION
//   Color get primaryColor => isMessagedly ? const Color(0xff4242D4) : const Color(0xFF00A884); // Messagedly par absolute Blue 🔵 / GetGabs par Green 🟢
//   Color get darkBgColor => isMessagedly ? const Color(0xff1A1A5E) : const Color(0xFF034737);   // Waves aur status ke liye dark variant
//   String _status = 'Connecting...';
//   Duration _duration = Duration.zero;
//   Timer? _timer;
//   bool _isMuted = false;
//   bool _isSpeaker = false;
//   bool _isConnected = false;
//   bool _isEnded = false;
//   bool _isExternalService = false;

//   late AnimationController _waveController;

//   @override
//   void initState() {
//     super.initState();
//     _waveController =
//         AnimationController(duration: const Duration(seconds: 2), vsync: this)
//           ..repeat();
//     SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
//       statusBarColor: Colors.transparent,
//       statusBarIconBrightness: Brightness.dark,
//     ));
//     _initCall();
//   }

//   Future<void> _initCall() async {
//     // ✅ Step 1: Global service reuse karo agar socket connected ho
//     if (GlobalCallListenerService.instance.isInitialized &&
//         GlobalCallListenerService.instance.service != null &&
//         GlobalCallListenerService.instance.service!.socket?.connected == true) {
//       _callingService = GlobalCallListenerService.instance.service;
//       _isExternalService = true;
//       debugPrint('✅ Reusing global service socket');
//     } else {
//       // ✅ Step 2: Global listener reinitialize karo
//       debugPrint('⚠️ Global service not available, reinitializing...');
//       await WhatsAppCallingConfig.initializeCallListener();

//       if (GlobalCallListenerService.instance.isInitialized &&
//           GlobalCallListenerService.instance.service != null) {
//         _callingService = GlobalCallListenerService.instance.service;
//         _isExternalService = true;
//         debugPrint('✅ Reusing reinitialized global service');
//       } else {
//         // ✅ Step 3: Last resort — naya service banao
//         _callingService = WhatsAppCallingService(
//           userId: widget.userId,
//           adminId: widget.adminId,
//           userRole: 'agent',
//           businessApiKey: widget.businessApiKey,
//         );
//         _isExternalService = false;
//         await _callingService!.initialize();
//         debugPrint('✅ Created new service');
//       }
//     }

//     // ✅ Callbacks setup karo
//     _callingService!.onStatusChange = (s) {
//       if (!mounted || _isEnded) return;
//       final statusLower = s.toLowerCase();
//       debugPrint('📞 Status changed: $s');

//       if (statusLower.contains('connected')) {
//         setState(() {
//           _isConnected = true;
//           _status = 'Connected';
//         });
//         _startTimer();
//       } else if (statusLower.contains('accepted')) {
//         setState(() => _status = 'Ringing...');
//       } else if (statusLower.contains('ringing') ||
//           statusLower.contains('calling')) {
//         setState(() {
//           _isConnected = false;
//           _status = 'Connecting...';
//         });
//       } else if (statusLower.contains('no answer') ||
//           statusLower.contains('unavailable')) {
//         _handleCallEnded('No answer');
//       } else if (statusLower.contains('busy')) {
//         _handleCallEnded('User is busy');
//       } else if (statusLower.contains('declined') ||
//           statusLower.contains('rejected')) {
//         _handleCallEnded('Call declined');
//       } else if (statusLower.contains('ended') ||
//           statusLower.contains('failed') ||
//           statusLower.contains('terminated')) {
//         _handleCallEnded(s);
//       } else {
//         setState(() => _status = s);
//       }
//     };

//     _callingService!.onCallEnded = () {
//       debugPrint('📴 onCallEnded triggered');
//       _handleCallEnded('Call ended');
//     };

//     _callingService!.onError = (e) {
//       debugPrint('❌ Call error: $e');
//       if (mounted && !_isEnded) _handleCallEnded(e);
//     };

//     // ✅ Step 4: Incoming ya Outgoing
//     if (widget.isIncoming) {
//       // ✅ FIX: answerCall() call karo — pehle nahi hota tha!
//       setState(() => _status = 'Connecting...');
//       try {
//         // Service aur socket ready hone ka wait karo
//         await Future.delayed(const Duration(milliseconds: 300));

//         // ✅ Socket connected check karo
//         if (_callingService!.socket?.connected != true) {
//           debugPrint('⏳ Waiting for socket connection...');
//           int wait = 0;
//           while (_callingService!.socket?.connected != true && wait < 30) {
//             await Future.delayed(const Duration(milliseconds: 200));
//             wait++;
//           }
//           debugPrint(
//               '🔌 Socket after wait: ${_callingService!.socket?.connected}');
//         }

//         // ✅ Pending call check karo
//         if (_callingService!.hasActivePendingCall) {
//           debugPrint('✅ hasActivePendingCall = true, calling answerCall()...');
//           await _callingService!.answerCall();
//         } else {
//           debugPrint('❌ No pending call found — call may have expired');
//           _handleCallEnded('Call expired');
//         }
//       } catch (e) {
//         debugPrint('❌ answerCall error: $e');
//         _handleCallEnded(e.toString().replaceAll('Exception: ', ''));
//       }
//     } else if (widget.initialPhoneNumber.isNotEmpty) {
//       // ✅ Outgoing call
//       setState(() => _status = 'Calling...');
//       try {
//         if (_callingService!.socket?.connected != true) {
//           debugPrint('⏳ Waiting for socket before makeCall...');
//           int wait = 0;
//           while (_callingService!.socket?.connected != true && wait < 30) {
//             await Future.delayed(const Duration(milliseconds: 200));
//             wait++;
//           }
//           debugPrint(
//               '🔌 Socket after wait: ${_callingService!.socket?.connected}');
//         }
//         await _callingService!.makeCall(widget.initialPhoneNumber);
//       } catch (e) {
//         _handleCallEnded(e.toString().replaceAll('Exception: ', ''));
//       }
//     }
//   }

//   void _handleCallEnded(String reason) {
//     if (_isEnded) return;

//     debugPrint('📴 Handling call end: $reason');
//     _timer?.cancel();

//     if (mounted) {
//       setState(() {
//         _status = reason;
//         _isEnded = true;
//         _isConnected = false;
//       });

//       Future.delayed(const Duration(milliseconds: 1500), () {
//         if (mounted) Get.back();
//       });
//     }
//   }

//   void _startTimer() {
//     _timer?.cancel();
//     _timer = Timer.periodic(const Duration(seconds: 1), (_) {
//       if (mounted && !_isEnded) {
//         setState(() => _duration += const Duration(seconds: 1));
//       }
//     });
//   }

//   String _formatDuration(Duration d) {
//     String twoDigits(int n) => n.toString().padLeft(2, '0');
//     if (d.inHours > 0) {
//       return '${twoDigits(d.inHours)}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}';
//     }
//     return '${twoDigits(d.inMinutes)}:${twoDigits(d.inSeconds.remainder(60))}';
//   }

//   void _toggleMute() {
//     setState(() => _isMuted = !_isMuted);
//     _callingService?.localStream
//         ?.getAudioTracks()
//         .forEach((t) => t.enabled = !_isMuted);
//     HapticFeedback.lightImpact();
//   }

//   void _toggleSpeaker() {
//     setState(() => _isSpeaker = !_isSpeaker);
//     HapticFeedback.lightImpact();
//   }

//   void _endCall() {
//     HapticFeedback.mediumImpact();
//     _callingService?.terminateCall();
//   }

//   String _getInitials(String name, String number) {
//     if (name.isNotEmpty && !_isOnlyNumbers(name)) {
//       final words = name.trim().split(RegExp(r'\s+'));
//       if (words.length >= 2 &&
//           words[0].isNotEmpty &&
//           words[1].isNotEmpty) {
//         return '${words[0][0]}${words[1][0]}'.toUpperCase();
//       } else if (words.isNotEmpty && words[0].isNotEmpty) {
//         return words[0][0].toUpperCase();
//       }
//     }
//     String cleaned = number.replaceAll(RegExp(r'[^\d]'), '');
//     if (cleaned.length >= 2) {
//       return cleaned.substring(cleaned.length - 2);
//     } else if (cleaned.isNotEmpty) {
//       return cleaned;
//     }
//     return '?';
//   }

//   bool _isOnlyNumbers(String text) {
//     return RegExp(r'^[\d\s\+\-\(\)]+$').hasMatch(text);
//   }

//   String _getDisplayName() {
//     if (widget.contactName.isNotEmpty && !_isOnlyNumbers(widget.contactName)) {
//       return widget.contactName;
//     }
//     return _formatPhoneDisplay(widget.initialPhoneNumber);
//   }

//   String _formatPhoneDisplay(String phone) {
//     String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
//     if (cleaned.startsWith('+91') && cleaned.length == 13) {
//       return '+91 ${cleaned.substring(3, 99)} ${cleaned.substring(99)}';
//     } else if (cleaned.startsWith('91') && cleaned.length == 12) {
//       return '+91 ${cleaned.substring(2, 7)} ${cleaned.substring(7)}';
//     }
//     return phone;
//   }

//   bool _shouldShowPhoneNumber() {
//     final displayName = _getDisplayName();
//     final formattedPhone = _formatPhoneDisplay(widget.initialPhoneNumber);
//     return displayName != formattedPhone && widget.initialPhoneNumber.isNotEmpty;
//   }

//   @override
//   void dispose() {
//     _waveController.dispose();
//     _timer?.cancel();

//     if (_isExternalService) {
//       // ✅ Sirf callbacks hatao, socket alive rehne do
//       _callingService?.onStatusChange = null;
//       _callingService?.onCallEnded = null;
//       _callingService?.onError = null;
//     } else {
//       _callingService?.dispose();
//     }

//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final displayName = _getDisplayName();
//     final initials =
//         _getInitials(widget.contactName, widget.initialPhoneNumber);

//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Container(
//         decoration: const BoxDecoration(
//           gradient: LinearGradient(
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             colors: [
//               Color(0xFFF5F5F5),
//               Colors.white,
//               Color(0xFFFAFAFA),
//             ],
//             stops: [0.0, 0.3, 1.0],
//           ),
//         ),
//         child: SafeArea(
//           child: Column(
//             children: [
//               // Top bar
//               Padding(
//                 padding: const EdgeInsets.all(8),
//                 child: Row(
//                   children: [
//                     IconButton(
//                       icon: const Icon(Icons.arrow_back,
//                           color: Color(0xFF1F2C34)),
//                       onPressed: () {
//                         _callingService?.terminateCall();
//                         Get.back();
//                       },
//                     ),
//                     const Spacer(),
//                     if (_isConnected && !_isEnded)
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                             horizontal: 10, vertical: 4),
//                         decoration: BoxDecoration(
//                           color: const Color(0xFF034737).withOpacity(0.1),
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         child: Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             Container(
//                               width: 6,
//                               height: 6,
//                               decoration: const BoxDecoration(
//                                   color: Color(0xFF034737),
//                                   shape: BoxShape.circle),
//                             ),
//                             const SizedBox(width: 4),
//                             const Text('Encrypted',
//                                 style: TextStyle(
//                                     color: Color(0xFF00A884),
//                                     fontSize: 11,
//                                     fontWeight: FontWeight.w500)),
//                           ],
//                         ),
//                       ),
//                     const Spacer(),
//                     const SizedBox(width: 48),
//                   ],
//                 ),
//               ),

//               const Spacer(),

//               // Avatar with waves
//               Stack(
//                 alignment: Alignment.center,
//                 children: [
//                   if (!_isConnected && !_isEnded)
//                     AnimatedBuilder(
//                       animation: _waveController,
//                       builder: (context, child) => CustomPaint(
//                         size: const Size(200, 200),
//                         painter: _WavePainter(
//                           animationValue: _waveController.value,
//                           color: const Color(0xFF034737),
//                         ),
//                       ),
//                     ),
//                   Container(
//                     width: 110,
//                     height: 110,
//                     decoration: BoxDecoration(
//                       shape: BoxShape.circle,
//                       color: _isEnded
//                           ? Colors.grey[400]
//                           : const Color(0xFF00A884),
//                       boxShadow: _isEnded
//                           ? null
//                           : [
//                               BoxShadow(
//                                 color:
//                                     const Color(0xFF00A884).withOpacity(0.25),
//                                 blurRadius: 25,
//                                 spreadRadius: 3,
//                               ),
//                             ],
//                     ),
//                     child: Center(
//                       child: Text(
//                         initials,
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 38,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ),
//                   ),
//                 ],
//               ),

//               const SizedBox(height: 24),

//               // Display Name
//               Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 20),
//                 child: Text(
//                   displayName,
//                   style: const TextStyle(
//                     color: Color(0xFF1F2C34),
//                     fontSize: 26,
//                     fontWeight: FontWeight.w600,
//                   ),
//                   textAlign: TextAlign.center,
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//               ),

//               const SizedBox(height: 8),

//               // Phone number
//               if (_shouldShowPhoneNumber())
//                 Text(
//                   _formatPhoneDisplay(widget.initialPhoneNumber),
//                   style: TextStyle(color: Colors.grey[600], fontSize: 15),
//                 ),

//               const SizedBox(height: 16),

//               // Status / Duration
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   if (!_isConnected &&
//                       !_isEnded &&
//                       (_status == 'Calling...' ||
//                           _status == 'Ringing...' ||
//                           _status == 'Connecting...'))
//                     Container(
//                       width: 12,
//                       height: 12,
//                       margin: const EdgeInsets.only(right: 8),
//                       child: const CircularProgressIndicator(
//                         strokeWidth: 2,
//                         color: Color(0xFF00A884),
//                       ),
//                     ),
//                   Text(
//                     _isConnected && !_isEnded
//                         ? _formatDuration(_duration)
//                         : _status,
//                     style: TextStyle(
//                       color: _isEnded
//                           ? Colors.redAccent
//                           : _isConnected
//                               ? const Color(0xFF00A884)
//                               : Colors.grey[600],
//                       fontSize: _isConnected ? 20 : 15,
//                       fontWeight: _isConnected
//                           ? FontWeight.w600
//                           : FontWeight.normal,
//                     ),
//                   ),
//                 ],
//               ),

//               const Spacer(),

//               // Controls
//               if (!_isEnded)
//                 Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 16),
//                   child: Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                     children: [
//                       _buildControlButton(
//                         _isSpeaker
//                             ? Icons.volume_up
//                             : Icons.volume_up_outlined,
//                         'Speaker',
//                         _isSpeaker,
//                         _toggleSpeaker,
//                       ),
//                       _buildControlButton(
//                         Icons.videocam_off_outlined,
//                         'Video',
//                         false,
//                         () {},
//                         isDisabled: true,
//                       ),
//                       _buildControlButton(
//                         _isMuted ? Icons.mic_off : Icons.mic_none,
//                         'Mute',
//                         _isMuted,
//                         _toggleMute,
//                       ),
//                     ],
//                   ),
//                 ),

//               SizedBox(height: _isEnded ? 20 : 30),

//               // End call button
//               GestureDetector(
//                 onTap: _isEnded ? () => Get.back() : _endCall,
//                 child: Container(
//                   width: 65,
//                   height: 65,
//                   decoration: BoxDecoration(
//                     color: _isEnded
//                         ? Colors.grey[400]
//                         : const Color(0xFFEA4335),
//                     shape: BoxShape.circle,
//                     boxShadow: _isEnded
//                         ? null
//                         : [
//                             BoxShadow(
//                               color: const Color(0xFFEA4335).withOpacity(0.35),
//                               blurRadius: 12,
//                               offset: const Offset(0, 4),
//                             ),
//                           ],
//                   ),
//                   child: Icon(
//                     _isEnded ? Icons.close : Icons.call_end,
//                     color: Colors.white,
//                     size: 28,
//                   ),
//                 ),
//               ),

//               const SizedBox(height: 8),

//               if (_isEnded)
//                 Text(
//                   'Close',
//                   style: TextStyle(color: Colors.grey[600], fontSize: 12),
//                 ),

//               const SizedBox(height: 40),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildControlButton(
//     IconData icon,
//     String label,
//     bool isActive,
//     VoidCallback onTap, {
//     bool isDisabled = false,
//   }) {
//     return GestureDetector(
//       onTap: isDisabled ? null : onTap,
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             width: 50,
//             height: 50,
//             decoration: BoxDecoration(
//               color: isActive
//                   ? const Color(0xFF00A884)
//                   : isDisabled
//                       ? Colors.grey[200]
//                       : Colors.grey[100],
//               shape: BoxShape.circle,
//               border: Border.all(
//                 color: isActive
//                     ? const Color(0xFF00A884)
//                     : Colors.grey[300]!,
//                 width: 1,
//               ),
//             ),
//             child: Icon(
//               icon,
//               color: isActive
//                   ? Colors.white
//                   : isDisabled
//                       ? Colors.grey[400]
//                       : const Color(0xFF1F2C34),
//               size: 22,
//             ),
//           ),
//           const SizedBox(height: 6),
//           Text(
//             label,
//             style: TextStyle(
//               color: isDisabled ? Colors.grey[400] : Colors.grey[700],
//               fontSize: 11,
//               fontWeight: FontWeight.w500,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // Wave Painter
// class _WavePainter extends CustomPainter {
//   final double animationValue;
//   final Color color;

//   _WavePainter({required this.animationValue, required this.color});

//   @override
//   void paint(Canvas canvas, Size size) {
//     final center = Offset(size.width / 2, size.height / 2);
//     for (int i = 0; i < 3; i++) {
//       double progress = (animationValue + i * 0.33) % 1.0;
//       double radius = 55 + (progress * 45);
//       double opacity = (1 - progress) * 0.4;
//       final paint = Paint()
//         ..color = color.withOpacity(opacity)
//         ..style = PaintingStyle.stroke
//         ..strokeWidth = 2;
//       canvas.drawCircle(center, radius, paint);
//     }
//   }

//   @override
//   bool shouldRepaint(_WavePainter oldDelegate) =>
//       oldDelegate.animationValue != animationValue;
// }

