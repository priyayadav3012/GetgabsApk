import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getgabs/data/models/active_chat_model.dart';
import 'package:getgabs/domain/controllers/auth/login_with_email/login_with_email_controller.dart';
import 'package:getgabs/ui/pages/dashboard/chats/messages_ui/messages_page.dart';
import 'package:getgabs/ui/themes/themes.dart';
import 'package:intl/intl.dart';
import '../../../../../domain/controllers/dashboard/dashboard_controller.dart';

class ActiveChatListTile extends StatelessWidget {
  final Profile profile;
  final DashboardController dashboardController = Get.put(DashboardController());
  ActiveChatListTile({super.key, required this.profile});

  // ✅ Flavor check — same as api_end_points.dart
    static bool get _isMessagedly =>
      LoginWithEmailController.currentFlavorNormalized == 'messagedly';

    static bool get _isScalewiz =>
      LoginWithEmailController.currentFlavorNormalized == 'scalewiz';

  static Color get _brandColor => _isMessagedly
      ? const Color(0xff4242D4)
      : _isScalewiz
          ? const Color(0xff17A398)
          : const Color(0xFF25D366);

  @override
  Widget build(BuildContext context) {
    final safeName = cleanName(profile.profileName);
    final Color brandColor = _brandColor;

    return InkWell(
      onTap: () {
        Get.to(() => MessagesPage(
              profile: profile,
              profileWaKey: profile.profileWaKey,
            ));
      },
      child: Column(
        children: [
          ListTile(
            tileColor: profile.getPendingMsgCount > 0
                ? brandColor.withOpacity(0.1)
                : null,
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: getAvatarBgColor(safeDecode(safeName)),
              child: Text(
                getInitialsSafe(safeName),
                style: TextStyle(
                  color: getAvatarTextColor(safeDecode(safeName)),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            title: Text(
              safeName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
            subtitle: const Text(
              "Click to view",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: Colors.blueGrey),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                /// ✅ Date/time — brand color if unread
                Text(
                  formatChatDate(profile.updatedTime),
                  style: TextStyle(
                    fontSize: 12,
                    color: profile.getPendingMsgCount > 0
                        ? brandColor
                        : Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),

                /// ✅ Unread badge — brand color
                if (profile.getPendingMsgCount > 0)
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: brandColor,
                    child: Center(
                      child: Text(
                        profile.getPendingMsgCount.toString(),
                        style: const TextStyle(fontSize: 11, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
              height: 0,
              thickness: 0.5,
              color: brandColor.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Safe Decode
String safeDecode(String? text) {
  if (text == null || text.isEmpty) return '';
  try {
    return utf8.decode(text.runes.toList(), allowMalformed: true);
  } catch (e) {
    return text;
  }
}

/// getInitialsSafe
String getInitialsSafe(String? name) {
  if (name == null) return '?';
  final safeName = name.trim();
  if (safeName.isEmpty) return '?';

  final chars = safeName.characters.toList();
  if (chars.isEmpty) return '?';

  final words = safeName.split(' ').where((e) => e.trim().isNotEmpty).toList();
  if (words.isEmpty) return chars.first;

  if (words.length == 1) {
    final firstWordChars = words[0].characters.toList();
    if (firstWordChars.isEmpty) return '?';
    return firstWordChars.first.toUpperCase();
  }

  final firstChars = words[0].characters.toList();
  final secondChars = words[1].characters.toList();
  if (firstChars.isEmpty) return '?';

  final first = firstChars.first;
  final second = secondChars.isNotEmpty ? secondChars.first : '';
  return (first + second).toUpperCase();
}

/// Clean Name
String cleanName(String? name) {
  if (name == null || name.trim().isEmpty) return "Unknown";
  String cleaned = name.replaceAll(RegExp(r'[\u200E\u200F\u202A-\u202E]'), '');
  if (cleaned.trim().isEmpty) return "Unknown";
  return cleaned.trim();
}

/// Format Date
String formatChatDate(String dateString) {
  try {
    final messageDate = DateTime.parse(dateString);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDay = DateTime(messageDate.year, messageDate.month, messageDate.day);

    if (messageDay == today) return DateFormat('hh:mm a').format(messageDate);
    if (messageDay == yesterday) return "Yesterday";
    return DateFormat('EEE, dd MMM').format(messageDate);
  } catch (e) {
    return "";
  }
}

String getInitials(String name) {
  if (name.isEmpty) return "?";
  List<String> parts = name.trim().split(" ");
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return (parts[0][0] + parts[1][0]).toUpperCase();
}

Color getAvatarColor(String name) {
  final List<Color> colors = [
    const Color(0xFF25D366),
    const Color(0xFF128C7E),
    const Color(0xFF34B7F1),
    const Color(0xFF075E54),
    const Color(0xFFEA4335),
    const Color(0xFFFBBC05),
    const Color(0xFF9C27B0),
    const Color(0xFF3F51B5),
    const Color(0xFFFF5722),
    const Color(0xFF009688),
  ];
  int index = name.hashCode % colors.length;
  if (index < 0) index = -index;
  return colors[index];
}

Color getAvatarBgColor(String name) {
  final List<Color> colors = [
    const Color(0xFFE3F2FD),
    const Color(0xFFE8F5E9),
    const Color(0xFFFFF3E0),
    const Color(0xFFF3E5F5),
    const Color(0xFFFFEBEE),
    const Color(0xFFE0F2F1),
    const Color(0xFFFFFDE7),
    const Color(0xFFEDE7F6),
    const Color(0xFFE1F5FE),
    const Color(0xFFFCE4EC),
  ];
  int index = name.hashCode % colors.length;
  if (index < 0) index = -index;
  return colors[index];
}

Color getAvatarTextColor(String name) {
  final List<Color> colors = [
    const Color(0xFF1565C0),
    const Color(0xFF2E7D32),
    const Color(0xFFEF6C00),
    const Color(0xFF6A1B9A),
    const Color(0xFFC62828),
    const Color(0xFF00695C),
    const Color(0xFFF9A825),
    const Color(0xFF4527A0),
    const Color(0xFF0277BD),
    const Color(0xFFAD1457),
  ];
  int index = name.hashCode % colors.length;
  if (index < 0) index = -index;
  return colors[index];
}






// import 'dart:convert';

// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:getgabs/data/models/active_chat_model.dart';
// import 'package:getgabs/ui/pages/dashboard/chats/messages_ui/messages_page.dart';
// import 'package:getgabs/ui/themes/themes.dart';
// import 'package:intl/intl.dart';
// import '../../../../../domain/controllers/dashboard/dashboard_controller.dart';

// class ActiveChatListTile extends StatelessWidget {
//   final Profile profile;
//   final DashboardController dashboardController = Get.put(DashboardController());
//   ActiveChatListTile({super.key, required this.profile});

//   @override
//   Widget build(BuildContext context) {

//   final safeName = cleanName(profile.profileName);

//     return InkWell(
//       onTap: () {
//         // Get.toNamed(AppRoute.messagesPage);
//         Get.to(() => MessagesPage(
//               profile: profile,
//               profileWaKey: profile.profileWaKey,
//             ));

//         // dashboardController.loadChatsApi(userKey: profile.profileWaKey,from: 'outside');
//       },
//       child: Column(
//         children: [
//           ListTile(
//             tileColor: profile.getPendingMsgCount > 0 ? AppTheme.unreadMessagesColor.withOpacity(0.1) : null,
//         // tileColor: Colors.red,
//         // visualDensity: const VisualDensity(vertical: -4),
//         // dense: true,
//         // contentPadding: const EdgeInsets.zero(),
//         leading:
//         // CachedNetworkImage(
//           //   imageUrl: "https://ui-avatars.com/api/?name=${dashboardController.replaceFirstTwoSpaces(profile.profileName)}",
//           //   imageBuilder: (context, imageProvider) => Container(
//           //     decoration: BoxDecoration(
//           //       image: DecorationImage(
//           //           image: imageProvider,
//           //           fit: BoxFit.cover,
//           //           colorFilter:
//           //               ColorFilter.mode(Colors.red, BlendMode.colorBurn)),
//           //     ),
//           //   ),
//           //   placeholder: (context, url) => CircularProgressIndicator(),
//           //   errorWidget: (context, url, error) => Icon(Icons.error),
//           // ),
//         //  CircleAvatar(
//         //   backgroundImage: 
//         //   NetworkImage(
//         //     'https://ui-avatars.com/api/?name= ${dashboardController.replaceFirstTwoSpaces(profile.profileName)}',
//         //   ),
//         // ),
//         // CircleAvatar(
//         //   radius: 22,
//         //   backgroundColor: getAvatarBgColor(profile.profileName),
//         //   child: Text(
//         //     getInitials(profile.profileName),
//         //     style: TextStyle(
//         //       // color: Colors.white,
//         //       color: getAvatarTextColor(profile.profileName),
//         //       fontSize: 16,
//         //       fontWeight: FontWeight.w600,
//         //     ),
//         //   ),
//         // ),
//         CircleAvatar(
//           radius: 22,
//           backgroundColor: getAvatarBgColor(
//             safeDecode(safeName),
//           ),
//           child: Text(
//             getInitialsSafe(safeName),
//             style: TextStyle(
//               color: getAvatarTextColor(
//                 safeDecode(safeName),
//               ),
//               fontSize: 16,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//         ),
//         title: Text(
//           safeName,
//           maxLines: 2,
//           overflow: TextOverflow.ellipsis,
//           style: const TextStyle(
//             fontWeight: FontWeight.w500,
//             fontSize: 16,
//           ),
//         ),
//         subtitle: const Text(
//           "Click to view",
//           maxLines: 1,
//           overflow: TextOverflow.ellipsis,
//           style: TextStyle(
//             fontSize: 14,
//             color: Colors.blueGrey
//           ),
//         ),
//         trailing: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           crossAxisAlignment: CrossAxisAlignment.end,
//           children: [

//             /// ✅ Date text
//             Text(
//               formatChatDate(profile.updatedTime),
//               style: TextStyle(
//                 fontSize: 12,
//                 color: profile.getPendingMsgCount > 0
//                     ? Colors.green
//                     : Colors.grey,
//                 fontWeight: FontWeight.w500,
//               ),
//             ),

//             const SizedBox(height: 4),

//             /// ✅ Unread count
//             if (profile.getPendingMsgCount > 0)
//               CircleAvatar(
//                 radius: 10,
//                 backgroundColor: Colors.green,
//                 child: Center(
//                   child: Text(
//                     profile.getPendingMsgCount.toString(),
//                     style: const TextStyle(fontSize: 11, color: Colors.white),
//                   ),
//                 ),        
//               ),
//           ],
//         ),
//       ),
//           Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 16),
//             child: Divider(
//               height: 0,
//               thickness: 0.5,
//               color: AppTheme.unreadMessagesColor,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// /// Safe Decode
// String safeDecode(String? text) {
//   if (text == null || text.isEmpty) return '';

//   try {
//     return utf8.decode(text.runes.toList(), allowMalformed: true);
//   } catch (e) {
//     return text;
//   }
// }

// /// getInitialsSafe
// String getInitialsSafe(String? name) {
//   if (name == null) return '?';

//   final safeName = name.trim();

//   if (safeName.isEmpty) return '?';

//   // emoji safe characters list
//   final chars = safeName.characters.toList();

//   if (chars.isEmpty) return '?';

//   // split words safely (remove empty words)
//   final words = safeName
//       .split(' ')
//       .where((e) => e.trim().isNotEmpty)
//       .toList();

//   // agar emoji ya single char hai
//   if (words.isEmpty) {
//     return chars.first;
//   }

//   if (words.length == 1) {
//     final firstWordChars = words[0].characters.toList();
//     if (firstWordChars.isEmpty) return '?';
//     return firstWordChars.first.toUpperCase();
//   }

//   // multiple words initials
//   final firstChars = words[0].characters.toList();
//   final secondChars = words[1].characters.toList();

//   if (firstChars.isEmpty) return '?';

//   final first = firstChars.first;
//   final second = secondChars.isNotEmpty ? secondChars.first : '';

//   return (first + second).toUpperCase();
// }

// /// Clean Name
// String cleanName(String? name) {
//   if (name == null || name.trim().isEmpty) return "Unknown";

//   // Remove invisible unicode characters
//   String cleaned = name.replaceAll(RegExp(r'[\u200E\u200F\u202A-\u202E]'), '');

//   if (cleaned.trim().isEmpty) {
//     return "Unknown";
//   }

//   return cleaned.trim();
// }

// /// Format Date
// String formatChatDate(String dateString) {
//   try {
//     final messageDate = DateTime.parse(dateString);
//     final now = DateTime.now();

//     final today = DateTime(now.year, now.month, now.day);
//     final yesterday = today.subtract(const Duration(days: 1));
//     final messageDay =
//         DateTime(messageDate.year, messageDate.month, messageDate.day);

//     // ✅ Today → show time
//     if (messageDay == today) {
//       return DateFormat('hh:mm a').format(messageDate);
//     }

//     // ✅ Yesterday → show Yesterday
//     if (messageDay == yesterday) {
//       return "Yesterday";
//     }

//     // ✅ Older → show Tue, 25 Feb
//     return DateFormat('EEE, dd MMM').format(messageDate);
//   } catch (e) {
//     return "";
//   }
// }

// String getInitials(String name) {
//   if (name.isEmpty) return "?";

//   List<String> parts = name.trim().split(" ");

//   if (parts.length == 1) {
//     return parts[0][0].toUpperCase();
//   }

//   return (parts[0][0] + parts[1][0]).toUpperCase();
// }

// Color getAvatarColor(String name) {
//   final List<Color> colors = [
//     const Color(0xFF25D366), // WhatsApp green
//     const Color(0xFF128C7E),
//     const Color(0xFF34B7F1),
//     const Color(0xFF075E54),
//     const Color(0xFFEA4335),
//     const Color(0xFFFBBC05),
//     const Color(0xFF9C27B0),
//     const Color(0xFF3F51B5),
//     const Color(0xFFFF5722),
//     const Color(0xFF009688),
//   ];

//   int index = name.hashCode % colors.length;

//   if (index < 0) index = -index;

//   return colors[index];
// }

// Color getAvatarBgColor(String name) {
//   final List<Color> colors = [
//     const Color(0xFFE3F2FD), // light blue
//     const Color(0xFFE8F5E9), // light green
//     const Color(0xFFFFF3E0), // light orange
//     const Color(0xFFF3E5F5), // light purple
//     const Color(0xFFFFEBEE), // light red
//     const Color(0xFFE0F2F1), // light teal
//     const Color(0xFFFFFDE7), // light yellow
//     const Color(0xFFEDE7F6), // light indigo
//     const Color(0xFFE1F5FE), // light sky
//     const Color(0xFFFCE4EC), // light pink
//   ];

//   int index = name.hashCode % colors.length;
//   if (index < 0) index = -index;

//   return colors[index];
// }

// Color getAvatarTextColor(String name) {
//   final List<Color> colors = [
//     const Color(0xFF1565C0), // dark blue
//     const Color(0xFF2E7D32), // dark green
//     const Color(0xFFEF6C00), // dark orange
//     const Color(0xFF6A1B9A), // dark purple
//     const Color(0xFFC62828), // dark red
//     const Color(0xFF00695C), // dark teal
//     const Color(0xFFF9A825), // dark yellow
//     const Color(0xFF4527A0), // dark indigo
//     const Color(0xFF0277BD), // dark sky
//     const Color(0xFFAD1457), // dark pink
//   ];

//   int index = name.hashCode % colors.length;
//   if (index < 0) index = -index;

//   return colors[index];
// }