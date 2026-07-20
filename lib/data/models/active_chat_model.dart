// class ActiveChatModel {
//   final bool status;
//   final Message message;

//   ActiveChatModel({
//     required this.status,
//     required this.message,
//   });

//   factory ActiveChatModel.fromJson(Map<String, dynamic> json) {
//     return ActiveChatModel(
//       status: json['status'],
//       message: Message.fromJson(json['message']),
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'status': status,
//       'message': message.toJson(),
//     };
//   }
// }

// class Message {
//   final Data data;

//   Message({
//     required this.data,
//   });

//   factory Message.fromJson(Map<String, dynamic> json) {
//     return Message(
//       data: Data.fromJson(json['data']),
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'data': data.toJson(),
//     };
//   }
// }

// class Data {
//   final int currentPage;
//   final List<Profile> profiles;
//   final String firstPageUrl;
//   final int from;
//   final int lastPage;
//   final String lastPageUrl;
//   final List<Link> links;
//   final String nextPageUrl;
//   final String path;
//   final int perPage;
//   final String? prevPageUrl;
//   final int to;
//   final int total;

//   Data({
//     required this.currentPage,
//     required this.profiles,
//     required this.firstPageUrl,
//     required this.from,
//     required this.lastPage,
//     required this.lastPageUrl,
//     required this.links,
//     required this.nextPageUrl,
//     required this.path,
//     required this.perPage,
//     this.prevPageUrl,
//     required this.to,
//     required this.total,
//   });

//   factory Data.fromJson(Map<String, dynamic> json) {
//     var profilesFromJson = json['data'] as List;
//     List<Profile> profilesList = profilesFromJson.map((i) => Profile.fromJson(i)).toList();

//     var linksFromJson = json['links'] as List;
//     List<Link> linksList = linksFromJson.map((i) => Link.fromJson(i)).toList();

//     return Data(
//       currentPage: json['current_page'],
//       profiles: profilesList,
//       firstPageUrl: json['first_page_url'],
//       from: json['from'],
//       lastPage: json['last_page'],
//       lastPageUrl: json['last_page_url'],
//       links: linksList,
//       nextPageUrl: json['next_page_url'],
//       path: json['path'],
//       perPage: json['per_page'],
//       prevPageUrl: json['prev_page_url'],
//       to: json['to'],
//       total: json['total'],
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'current_page': currentPage,
//       'data': profiles.map((i) => i.toJson()).toList(),
//       'first_page_url': firstPageUrl,
//       'from': from,
//       'last_page': lastPage,
//       'last_page_url': lastPageUrl,
//       'links': links.map((i) => i.toJson()).toList(),
//       'next_page_url': nextPageUrl,
//       'path': path,
//       'per_page': perPage,
//       'prev_page_url': prevPageUrl,
//       'to': to,
//       'total': total,
//     };
//   }
// }

class Profile {
  final int profileWaId;
  final String profileWaKey;
  final String profileName;
  final int getPendingMsgCount;
  final String updatedTime;
  final bool hasVoiceCallingPermission;

  // ✅ Assignment state (customer-list API) — drives whether the Assign
  // dialog should offer a primary "Assign to" or only "Co-assign to".
  final int? assignedUserId;
  final String? assignedUserName;
  final int? assignedTeamId;
  final String? assignedTeamName;

  Profile({
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

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      profileWaId: int.tryParse(json['profile_wa_id'].toString()) ?? 0,
      profileWaKey: json['profile_wa_key'] ?? "",
      profileName: json['profile_name'] ?? "",
      getPendingMsgCount: int.tryParse(json['getpendingmsg_count'].toString()) ?? 0,
      updatedTime: json['updatedtime'] ?? "",
      hasVoiceCallingPermission:
          (json['hasVoiceCallingPermission'] ?? "no") == "yes",
      assignedUserId: int.tryParse(json['assigned_user']?.toString() ?? ''),
      assignedUserName: json['assigned_user_name'],
      assignedTeamId: int.tryParse(json['assigned_team_id']?.toString() ?? ''),
      assignedTeamName: json['assigned_team_name'],
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

  Profile copyWith({
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
    return Profile(
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
// class Profile {
//   final int profileWaId;
//   final String profileWaKey;
//   final String profileName;
//   final int getPendingMsgCount;

//   Profile({
//     required this.profileWaId,
//     required this.profileWaKey,
//     required this.profileName,
//     required this.getPendingMsgCount,
//   });

//   factory Profile.fromJson(Map<String, dynamic> json) {
//     return Profile(
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

//     Profile copyWith({
//     int? profileWaId,
//     String? profileWaKey,
//     String? profileName,
//     int? getPendingMsgCount,
//   }) {
//     return Profile(
//       profileWaId: profileWaId ?? this.profileWaId,
//       profileWaKey: profileWaKey ?? this.profileWaKey,
//       profileName: profileName ?? this.profileName,
//       getPendingMsgCount: getPendingMsgCount ?? this.getPendingMsgCount,
//     );
//   }

// }

// class Link {
//   final String? url;
//   final String label;
//   final bool active;

//   Link({
//     this.url,
//     required this.label,
//     required this.active,
//   });

//   factory Link.fromJson(Map<String, dynamic> json) {
//     return Link(
//       url: json['url'],
//       label: json['label'],
//       active: json['active'],
//     );
//   }

//   Map<String, dynamic> toJson() {
//     return {
//       'url': url,
//       'label': label,
//       'active': active,
//     };
//   }
// }
