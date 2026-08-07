// Models for the "Your Profile" screen.
// Fetch response shape (see mobile API doc):
// {
//   "status": true,
//   "message": { "data": { ...profile fields... } },
//   "countryCodes": [ { id, country_name, country_code } ],
//   "timezones":    [ { id, time_zone, gmt_offset } ]
// }

class ProfileDetail {
  final int id;
  final String name;
  final String email; // read-only
  final String phone; // full number with country code, e.g. 919079903443
  final String countryCode; // display value, e.g. "India (+91)"
  final String timezone; // e.g. "Asia/Kolkata"
  final String location;
  final String language;
  final String workingHours; // raw JSON string, parse client-side
  final String role; // read-only
  final String? profileImage;
  final String? profileImageUrl; // absolute URL, or null
  final String contactNumber; // local number, no country code

  ProfileDetail({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.countryCode,
    required this.timezone,
    required this.location,
    required this.language,
    required this.workingHours,
    required this.role,
    required this.profileImage,
    required this.profileImageUrl,
    required this.contactNumber,
  });

  factory ProfileDetail.fromJson(Map<String, dynamic> json) {
    return ProfileDetail(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      countryCode: json['country_code']?.toString() ?? '',
      timezone: json['timezone']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      language: json['language']?.toString() ?? '',
      workingHours: json['working_hours']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      profileImage: json['profile_image']?.toString(),
      profileImageUrl: json['profile_image_url']?.toString(),
      contactNumber: json['contact_number']?.toString() ?? '',
    );
  }
}

class CountryCodeItem {
  final int id;
  final String countryName;
  final String countryCode; // e.g. "+91"

  CountryCodeItem({
    required this.id,
    required this.countryName,
    required this.countryCode,
  });

  /// Matches the `country_code` display value returned in the profile,
  /// e.g. "India (+91)".
  String get display => '$countryName ($countryCode)';

  factory CountryCodeItem.fromJson(Map<String, dynamic> json) {
    return CountryCodeItem(
      id: json['id'] ?? 0,
      countryName: json['country_name']?.toString() ?? '',
      countryCode: json['country_code']?.toString() ?? '',
    );
  }
}

class TimezoneItem {
  final int id;
  final String timeZone; // e.g. "Asia/Kolkata"
  final String gmtOffset; // e.g. "+05:30"

  TimezoneItem({
    required this.id,
    required this.timeZone,
    required this.gmtOffset,
  });

  /// Human-readable label, e.g. "Asia/Kolkata (UTC +05:30)".
  String get display => '$timeZone (UTC $gmtOffset)';

  factory TimezoneItem.fromJson(Map<String, dynamic> json) {
    return TimezoneItem(
      id: json['id'] ?? 0,
      timeZone: json['time_zone']?.toString() ?? '',
      gmtOffset: json['gmt_offset']?.toString() ?? '',
    );
  }
}

/// A single working-hours slot for a day, stored as 24h "HH:mm".
class WorkingHoursSlot {
  String from;
  String to;

  WorkingHoursSlot({required this.from, required this.to});

  Map<String, String> toJson() => {'from': from, 'to': to};

  factory WorkingHoursSlot.fromJson(Map<String, dynamic> json) {
    return WorkingHoursSlot(
      from: json['from']?.toString() ?? '09:00',
      to: json['to']?.toString() ?? '18:00',
    );
  }
}
