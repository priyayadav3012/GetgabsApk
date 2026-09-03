import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
// Local Storage controller to handle persistent user session data on device cache
import 'package:getgabs/data/get_storage/get_storage.dart'; 
// Flavor helper used to distinguish between different multi-tenant app clients
import 'package:getgabs/domain/controllers/auth/login_with_email/login_with_email_controller.dart';
import 'package:getgabs/domain/controllers/more/ProfileController.dart';
import 'package:getgabs/domain/controllers/sockets/sockets_controller.dart';
import 'package:getgabs/domain/services/notifications_service/notification_service.dart';
import 'package:getgabs/routes/app_route.dart';
import 'package:getgabs/ui/res/assets/image_assets.dart';
import 'package:getgabs/ui/themes/themes.dart';
import 'package:package_info_plus/package_info_plus.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  DYNAMIC FLAVOR-SPECIFIC COLOR PALETTE & BRANDING CONFIG
// ─────────────────────────────────────────────────────────────────────────────
class _C {
  /// Evaluates whether the current active app compilation targets 'messagedly'
  static bool get isMessagedly => LoginWithEmailController.currentFlavorNormalized == 'messagedly';

  /// Evaluates whether the current active app compilation targets 'scalewiz'
  static bool get isScalewiz => LoginWithEmailController.currentFlavorNormalized == 'scalewiz';

  // Constant global canvas deep background color setup
  static const bg        = Color(0xFF0A0F0D);

  // Custom theme properties switching on the basis of active target flavor configuration
  static Color get card      => isMessagedly ? const Color(0xFF13111C) : isScalewiz ? const Color(0xFF0F1E1C) : const Color(0xFF162019);
  static Color get green     => isMessagedly ? const Color.fromARGB(255, 150, 107, 219) : isScalewiz ? const Color(0xff17A398) : const Color(0xFF25D366);
  static Color get greenDark => isMessagedly ? const Color.fromARGB(255, 125, 139, 216) : isScalewiz ? const Color(0xff0E7C74) : const Color(0xFF128C7E);
  static Color get border    => isMessagedly ? const Color.fromARGB(33, 164, 135, 245) : isScalewiz ? const Color(0x2217A398) : const Color(0x2225D366);
  static Color get text      => isMessagedly ? const Color.fromARGB(255, 229, 231, 248) : isScalewiz ? const Color(0xFFE9F7F4) : const Color(0xFFF0FAF4);
  static Color get muted     => isMessagedly ? const Color.fromARGB(255, 164, 135, 245) : isScalewiz ? const Color(0xff5FA79D) : const Color(0xFF6B8F79);
  
  // Destructive alert or global warning visual layout configuration color
  static const red       = Color(0xFFFF5A5A);
}

// ─────────────────────────────────────────────────────────────────────────────
//  MORE SCREEN  —  StatefulWidget for Settings, Profiling & Logout Operations
// ─────────────────────────────────────────────────────────────────────────────
class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});

  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> with SingleTickerProviderStateMixin {

  // Now registered again (see DashboardBinding) but kept nullable/guarded
  // here regardless, in case this screen is ever reachable before dashboard
  // binding runs. NOTE: Get.find() must be explicitly typed — inferring it
  // from this field's (nullable) declared type would look up a
  // "SocketsController?" registration, which never matches the
  // "SocketsController" Get.put() actually registered, and throws.
  final SocketsController? _socketsController =
      Get.isRegistered<SocketsController>()
          ? Get.find<SocketsController>()
          : null;
  // Fetch cloud-synchronized user entity profile variables
  final ProfileController profileController = Get.put(ProfileController());

  // Controls staggered entry transitions during render life-cycles
  late final AnimationController _entryCtrl;

  // Holds native platform application build strings fetched via platform-channels
  String appVersion = '';

  @override
  void initState() {
    super.initState();
    loadAppVersion(); // Triggers device native bridge call
    
    // Configures 800ms UI micro-interaction animation sequence initialization
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward(); // Begins forward playback sequence
  }

  @override
  void dispose() {
    _entryCtrl.dispose(); // Cleans memory allocations to avoid potential memory leak contexts
    super.dispose();
  }

  /// Communicates with native OS host architecture to safely resolve current metadata version
  Future<void> loadAppVersion() async {
    final info = await PackageInfo.fromPlatform();

    setState(() {
      appVersion = info.version; // Updates layout target view with verified app version
    });
  }

  // ── Transition Multipliers & Curves ──
  Animation<double> _opacity(double from, double to) =>
      Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _entryCtrl,
          curve: Interval(from, to, curve: Curves.easeOut),
        ),
      );

  Animation<Offset> _offset(double from, double to) =>
      Tween<Offset>(begin: const Offset(0, 0.18), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _entryCtrl,
          curve: Interval(from, to, curve: Curves.easeOut),
        ),
      );

  /// Launches an explicit verification check via native interactive model prior to erasing authentication cache state
  // void _handleSignOut() {
  //   showCupertinoDialog(
  //     context: context,
  //     builder: (_) => CupertinoAlertDialog(
  //       title: const Text(
  //         'Confirm Logout',
  //         style: TextStyle(fontWeight: FontWeight.w600),
  //       ),
  //       content: const Padding(
  //         padding: EdgeInsets.only(top: 8),
  //         child: Text(
  //           'Are you sure you want to log out?',
  //           style: TextStyle(fontSize: 15),
  //         ),
  //       ),
  //       actions: [
  //         // Dismisses alert popover state tree safe context rollback execution
  //         CupertinoDialogAction(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text('Cancel'),
  //         ),
  //         // Destructive transaction sequence execution branch logic pipeline
  //         CupertinoDialogAction(
  //           isDestructiveAction: true,
  //           onPressed: () async {
  //             Navigator.pop(context); // Dismisses modal prompt layout safely
  //             try {
  //               // Step 1: Firebase Cloud Messaging background target topic unsubscribe hook invocation
  //               NotificationService notificationService = NotificationService();
  //               notificationService.onUnsubscribeTopic();

  //               // Step 2: Disconnects active web gateway network server connections
  //               _socketsController.disconnectSocket();

  //               // Step 3: Wipes local hardware user data security cache indices 
  //               GetStorageUserData userData = GetStorageUserData();
  //               userData.clearAllData();

  //               // Step 4: Triggers complete page replacement stack routing to root login module
  //               Get.offAllNamed(AppRoute.loginWithEmail);
  //             } catch (e) {
  //               // Log exceptional data failures during cleanup steps
  //               debugPrint('Logout error: $e');
  //             }
  //           },
  //           child: const Text('Logout'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

/// Launches an explicit verification check via native interactive model prior to erasing authentication cache state
  void _handleSignOut() {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text(
          'Confirm Logout',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: const Padding(
          padding: EdgeInsets.only(top: 8),
          // Short description adjusted safely
          child: Text(
            'Are you sure you want to log out?',
            style: TextStyle(fontSize: 15),
          ),
        ),
        actions: [
          // Dismisses alert popover state tree safe context rollback execution
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          // Destructive transaction sequence execution branch logic pipeline
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context); // Dismisses modal prompt layout safely
              try {
                // Step 1: Firebase Cloud Messaging background target topic unsubscribe hook invocation
                // Awaited so it fully finishes (including its iOS APNS token
                // check) before deleteToken() below touches the same FCM
                // instance — racing them previously stalled the platform
                // channel on iOS and caused a late duplicate navigation back
                // to the login screen after a subsequent re-login.
                NotificationService notificationService = NotificationService();
                await notificationService.onUnsubscribeTopic();

                // 🔥 CRITICAL FIX: Delete the hardware instance token from Firebase Messaging
                // This ensures Ghost Notifications stop immediately for this user session.
                await FirebaseMessaging.instance.deleteToken();

                // Step 2: Disconnects active web gateway network server connections
                _socketsController?.disconnectSocket();

                // Step 3: Wipes local hardware user data security cache indices 
                GetStorageUserData userData = GetStorageUserData();
                userData.clearAllData();

                // Step 4: Triggers complete page replacement stack routing to root login module
                Get.offAllNamed(AppRoute.loginWithEmail);
              } catch (e) {
                // Log exceptional data failures during cleanup steps
                debugPrint('Logout error: $e');
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    // Dynamic screen frame boundary coordinate evaluation
    final mq = MediaQuery.of(context).size;
    final wp = mq.width;
    final hp = mq.height;

    return Scaffold(
      backgroundColor: _C.text, // Modulates dynamically to target client configuration
      body: Stack(
        children: [

          // ── Decorative Background Visual Accent Blob ──────────────────────────────
          Positioned(
            top: -wp * 0.25,
            right: -wp * 0.20,
            child: Container(
              width: wp * 0.75,
              height: wp * 0.75,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _C.green.withOpacity(0.07), // Swaps custom accent tint based on target client identity
              ),
            ),
          ),

          // ── Tech Blueprint Overlay Background Matrix lines ─────────────────────
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),

          // ── Screen Content Layout Construction Area ─────────────────────────
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Header Component section
                _FadeSlide(
                  opacity: _opacity(0.00, 0.45),
                  offset:  _offset(0.00, 0.45),
                  child: _buildHeader(wp),
                ),

                // Interactive Primary Identity Profile Panel Container card
                _FadeSlide(
                  opacity: _opacity(0.10, 0.55),
                  offset:  _offset(0.10, 0.55),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: wp * 0.05, vertical: hp * 0.015),
                    child: _buildProfileCard(),
                  ),
                ),

                SizedBox(height: hp * 0.008),

                // Category Section Header Identifier Label
                _FadeSlide(
                  opacity: _opacity(0.20, 0.60),
                  offset:  _offset(0.20, 0.60),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: wp * 0.055),
                    child: Text(
                      'SETTINGS',
                      style: TextStyle(
                          color: _C.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5),
                    ),
                  ),
                ),

                SizedBox(height: hp * 0.012),

                // Navigational Settings Feature Group Block
                _FadeSlide(
                  opacity: _opacity(0.28, 0.70),
                  offset:  _offset(0.28, 0.70),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: wp * 0.05),
                    child: _MenuCard(
                      items: [
                        _MenuItemData(
                          iconPath:    ImageAssets.circleUserRoundIcon,
                          label:       'Profile',
                          subtitle:    'View your profile',
                          iconBgColor: _C.green, // Dynamic client system visual color key binding map configuration
                          showProfilePhoto: true, // show uploaded photo here
                          onTap:       () => Get.toNamed(AppRoute.profileDetailsPage),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: hp * 0.022),

                // Secondary Operations Action Identifier text
                _FadeSlide(
                  opacity: _opacity(0.40, 0.80),
                  offset:  _offset(0.40, 0.80),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: wp * 0.055),
                    child: Text(
                      'ACCOUNT',
                      style: TextStyle(
                          color: _C.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5),
                    ),
                  ),
                ),

                SizedBox(height: hp * 0.012),

                // Danger/Destructive Account Actions Group Block
                _FadeSlide(
                  opacity: _opacity(0.46, 0.86),
                  offset:  _offset(0.46, 0.86),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: wp * 0.05),
                    child: _MenuCard(
                      items: [
                        _MenuItemData(
                          iconPath:    ImageAssets.logoutIcon,
                          label:       'Sign Out',
                          subtitle:    'Log out from your account',
                          iconBgColor: _C.red,
                          labelColor:  _C.red,
                          onTap:       _handleSignOut,
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(), // Shifts device version information footer layout to absolute layout baseline anchor

                // Platform Version & Client Branding Bottom Metadata Block
                _FadeSlide(
                  opacity: _opacity(0.60, 1.00),
                  offset:  _offset(0.60, 1.00),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: hp * 0.025),
                    child: Center(
                      child: Column(
                        children: [
                          // Dynamic Branding Text condition applied based on active target compilation client flavor
                          Text(
                            _C.isMessagedly
                                ? 'Powered by Messagedly'
                                : _C.isScalewiz
                                    ? 'Powered by Scalewiz'
                                    : 'Powered by Getgabs',
                            style: TextStyle(
                              fontSize: 11,
                              color: _C.muted,
                              letterSpacing: 0.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Evaluates and renders application runtime metadata string safely resolved via platform channels
                          Text(
                            'Version $appVersion',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Screen Title Layout Component Generator ──────────────────────────────────────────────────────────
  Widget _buildHeader(double wp) {
    return Padding(
      padding: EdgeInsets.fromLTRB(wp * 0.055, 20, wp * 0.055, 4),
      child: Row(
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'More',
                  style: TextStyle(
                      color: _C.card,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5),
                ),
                TextSpan(
                  text: '.',
                  style: TextStyle(
                      color: _C.green,
                      fontSize: 26,
                      fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Profile Identity Container Card Block ────────────────────────────────────────────────────
  Widget _buildProfileCard() {
    return InkWell(
      onTap: (){},
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.border),
          boxShadow: [
            BoxShadow(
                color: _C.green.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            // User avatar: shows the uploaded profile photo when available,
            // otherwise falls back to the user's initials. Wrapped in Obx so it
            // updates the moment a new photo is saved on the profile screen.
            Obx(() {
              final photoUrl = profileController.profileImageUrl.value ?? '';
              final initials = Center(
                child: Text(
                  getInitialsSafe(profileController.userName.value),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800),
                ),
              );
              return Container(
                width: 52,
                height: 52,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [_C.green, _C.greenDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                        color: _C.green.withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: photoUrl.isEmpty
                    ? initials
                    : Image.network(
                        photoUrl,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        // Keep initials visible while the photo loads / on error.
                        loadingBuilder: (context, child, progress) =>
                            progress == null ? child : initials,
                        errorBuilder: (context, error, stack) => initials,
                      ),
              );
            }),
      
            const SizedBox(width: 14),
      
            // Identity Name & Email context string data block
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profileController.userName.value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: _C.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    profileController.email.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _C.muted, fontSize: 12),
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

// ─────────────────────────────────────────────────────────────────────────────
//  MENU DATA CONFIG STRUCTURE MODEL
// ─────────────────────────────────────────────────────────────────────────────
class _MenuItemData {
  final String       iconPath;
  final String       label;
  final String       subtitle;
  final Color        iconBgColor;
  final Color        labelColor;
  final VoidCallback onTap;
  // When true, the leading icon is replaced by the user's uploaded profile
  // photo (falls back to [iconPath] when there is no photo / it fails to load).
  final bool         showProfilePhoto;

  const _MenuItemData({
    required this.iconPath,
    required this.label,
    required this.subtitle,
    required this.iconBgColor,
    this.labelColor = const Color(0xFF13111C),
    required this.onTap,
    this.showProfilePhoto = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
//  MENU COMPONENT WRAPPER (Handles borders, layout blocks & listing dividers)
// ─────────────────────────────────────────────────────────────────────────────
class _MenuCard extends StatelessWidget {
  final List<_MenuItemData> items;
  const _MenuCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.whiteColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          final isLast = i == items.length - 1;
          return Column(
            children: [
              _MenuRow(item: items[i]),
              // Renders line splitter only if trailing components follow
              if (!isLast)
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0x1525D366),
                  indent: 64,
                  endIndent: 16,
                ),
            ],
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  INDIVIDUAL MENU BUTTON ITEM ROW COMPONENT
// ─────────────────────────────────────────────────────────────────────────────
class _MenuRow extends StatelessWidget {
  final _MenuItemData item;
  const _MenuRow({required this.item});

  // The user's uploaded profile photo for the Profile row, falling back to the
  // item's SVG icon while it loads / when there is no photo. Reactive so it
  // updates the instant a new photo is saved on the profile screen.
  Widget _profilePhotoOrIcon() {
    final Widget iconFallback = Padding(
      padding: const EdgeInsets.all(9),
      child: SvgPicture.asset(
        item.iconPath,
        colorFilter: ColorFilter.mode(item.iconBgColor, BlendMode.srcIn),
      ),
    );

    if (!Get.isRegistered<ProfileController>()) return iconFallback;
    final pc = Get.find<ProfileController>();

    return Obx(() {
      final url = pc.profileImageUrl.value ?? '';
      if (url.isEmpty) return iconFallback;
      return Image.network(
        url,
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : iconFallback,
        errorBuilder: (context, error, stack) => iconFallback,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              // Vector Svg Graphic Icon Frame box (or the profile photo for the
              // Profile item).
              Container(
                width: 40,
                height: 40,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: item.iconBgColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                      color: item.iconBgColor.withOpacity(0.25)),
                ),
                child: item.showProfilePhoto
                    ? _profilePhotoOrIcon()
                    : Padding(
                        padding: const EdgeInsets.all(9),
                        child: SvgPicture.asset(
                          item.iconPath,
                          colorFilter: ColorFilter.mode(
                              item.iconBgColor, BlendMode.srcIn),
                        ),
                      ),
              ),

              const SizedBox(width: 13),

              // Description Data Labels context block
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                          color: item.labelColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: TextStyle(
                          color: _C.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),

              // Trailing system navigational visual icon cue chevron
              Icon(Icons.arrow_forward_ios_rounded,
                  color: _C.muted.withOpacity(0.5), size: 13),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MICRO-INTERACTION ENTRY ANIMATION WRAPPER EXTENSION
// ─────────────────────────────────────────────────────────────────────────────
class _FadeSlide extends StatelessWidget {
  final Animation<double> opacity;
  final Animation<Offset> offset;
  final Widget child;

  const _FadeSlide({
    required this.opacity,
    required this.offset,
    required this.child,
  });

  @override
  Widget build(BuildContext context) =>
      FadeTransition(
        opacity: opacity,
        child: SlideTransition(position: offset, child: child),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
//  CUSTOM GRAPHIC BACKGROUND GRID LINE PAINTER OBJECT
// ─────────────────────────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Configures canvas line weight and dynamic system accent color mapping
    final p = Paint()
      ..color = _C.green.withOpacity(0.03) // Fixed: Updated to track flavor system colors automatically instead of hardcoded hex
      ..strokeWidth = 1;
      
    // Sweeps horizontal plane axis lines across limits
    for (double x = 0; x < size.width;  x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    // Sweeps vertical plane axis lines across limits
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_) => false; // Static structure grid template does not require dynamic context refreshes
}

/// Helper method to safely isolate and decode binary context character codes to Unicode safe text strings
String safeDecode(String? text) {
  if (text == null || text.isEmpty) return '';

  try {
    return utf8.decode(text.runes.toList(), allowMalformed: true);
  } catch (e) {
    return text;
  }
}

/// Extract first readable character symbol from an input string (Emoji & Complex Character set parsing aware)
String getInitialsSafe(String? name) {
  if (name == null || name.trim().isEmpty) return '';

  final safeName = name.trim();
  final chars = safeName.characters.toList();

  if (chars.isEmpty) return '';

  final firstChar = chars.first;

  if (chars.length == 1) {
    return firstChar;
  }

  final words = safeName.split(' ');
  if (words.isNotEmpty) {
    final first = words[0].characters.first;
    return (first).toUpperCase();
  }

  return firstChar.toUpperCase();
}