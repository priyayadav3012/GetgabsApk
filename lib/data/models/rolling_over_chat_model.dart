class RollingOverChatModel {
  final int profileWaId;
  final String profileWaKey;
  final String profileName;
  final int getPendingMsgCount;
  final String updatedTime;
  final bool hasVoiceCallingPermission;

  RollingOverChatModel({
    required this.profileWaId,
    required this.profileWaKey,
    required this.profileName,
    required this.getPendingMsgCount,
    required this.updatedTime,
    required this.hasVoiceCallingPermission,
  });

  factory RollingOverChatModel.fromJson(Map<String, dynamic> json) {
    return RollingOverChatModel(
      profileWaId:
          int.tryParse(json['profile_wa_id']?.toString() ?? '') ?? 0,

      profileWaKey:
          json['profile_wa_key']?.toString() ?? "",

      profileName:
          json['profile_name']?.toString() ?? "",

      getPendingMsgCount:
          int.tryParse(json['getpendingmsg_count']?.toString() ?? '') ?? 0,

      updatedTime:
          json['updatedtime']?.toString() ?? "",

      hasVoiceCallingPermission:
          json['hasVoiceCallingPermission']?.toString().toLowerCase() == "yes",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profile_wa_id': profileWaId,
      'profile_wa_key': profileWaKey,
      'profile_name': profileName,
      'getpendingmsg_count': getPendingMsgCount,
      'updatedtime': updatedTime,
      'hasVoiceCallingPermission':
          hasVoiceCallingPermission ? "yes" : "no",
    };
  }

  RollingOverChatModel copyWith({
    int? profileWaId,
    String? profileWaKey,
    String? profileName,
    int? getPendingMsgCount,
    String? updatedTime,
    bool? hasVoiceCallingPermission,
  }) {
    return RollingOverChatModel(
      profileWaId: profileWaId ?? this.profileWaId,
      profileWaKey: profileWaKey ?? this.profileWaKey,
      profileName: profileName ?? this.profileName,
      getPendingMsgCount:
          getPendingMsgCount ?? this.getPendingMsgCount,
      updatedTime: updatedTime ?? this.updatedTime,
      hasVoiceCallingPermission:
          hasVoiceCallingPermission ?? this.hasVoiceCallingPermission,
    );
  }
}
// class RollingOverChatModel {
//   final int profileWaId;
//   final String profileWaKey;
//   final String profileName;
//   final int getPendingMsgCount;

//   RollingOverChatModel({
//     required this.profileWaId,
//     required this.profileWaKey,
//     required this.profileName,
//     required this.getPendingMsgCount,
//   });

//   factory RollingOverChatModel.fromJson(Map<String, dynamic> json) {
//     return RollingOverChatModel(
//       profileWaId: json['profile_wa_id'],
//       profileWaKey: json['profile_wa_key'],
//       profileName: json['profile_name'],
//       getPendingMsgCount: json['getpendingmsg_count'],
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'profile_wa_id': profileWaId,
//       'profile_wa_key': profileWaKey,
//       'profile_name': profileName,
//       'getpendingmsg_count': getPendingMsgCount,
//     };
//   }
// }
