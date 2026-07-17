class RollingOverChatModel {
  final int profileWaId;
  final String profileWaKey;
  final String profileName;
  final int getPendingMsgCount;
  final String updatedTime;
  final bool hasVoiceCallingPermission;

  // ✅ Assignment state — same fields as active_chat_model.dart's Profile,
  // needed so the rolling-over → MessageRollingPage conversion in
  // rolling_over_list_tile.dart can carry them through to the Assign dialog.
  final int? assignedUserId;
  final String? assignedUserName;
  final int? assignedTeamId;
  final String? assignedTeamName;

  RollingOverChatModel({
    required this.profileWaId,
    required this.profileWaKey,
    required this.profileName,
    required this.getPendingMsgCount,
    required this.updatedTime,
    required this.hasVoiceCallingPermission,
    this.assignedUserId,
    this.assignedUserName,
    this.assignedTeamId,
    this.assignedTeamName,
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

      assignedUserId: int.tryParse(json['assigned_user']?.toString() ?? ''),
      assignedUserName: json['assigned_user_name']?.toString(),
      assignedTeamId:
          int.tryParse(json['assigned_team_id']?.toString() ?? ''),
      assignedTeamName: json['assigned_team_name']?.toString(),
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
      'assigned_user': assignedUserId,
      'assigned_user_name': assignedUserName,
      'assigned_team_id': assignedTeamId,
      'assigned_team_name': assignedTeamName,
    };
  }

  RollingOverChatModel copyWith({
    int? profileWaId,
    String? profileWaKey,
    String? profileName,
    int? getPendingMsgCount,
    String? updatedTime,
    bool? hasVoiceCallingPermission,
    int? assignedUserId,
    String? assignedUserName,
    int? assignedTeamId,
    String? assignedTeamName,
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
      assignedUserId: assignedUserId ?? this.assignedUserId,
      assignedUserName: assignedUserName ?? this.assignedUserName,
      assignedTeamId: assignedTeamId ?? this.assignedTeamId,
      assignedTeamName: assignedTeamName ?? this.assignedTeamName,
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
