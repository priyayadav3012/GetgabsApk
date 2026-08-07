import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../end_points/api_end_points.dart';
import '../../network/network_api_services.dart';

/// Talks to the two "Your Profile" endpoints:
///   POST /v2/flutterapplication/profile         (fetch, JSON)
///   POST /v2/flutterapplication/profile/update  (update, multipart/form-data)
class ProfileServices {
  final _apiService = NetworkApiServices();

  /// Fetch the profile plus the country-code and timezone dropdown lists.
  Future<dynamic> fetchProfile(Map<String, dynamic> data,
      {Map<String, String>? headers}) async {
    return _apiService.postApi(
      data,
      ApiEndPoints.baseUrl + ApiEndPoints.moreScreenEndPoints.profileUrl,
      headers: headers,
    );
  }

  /// Update the profile. Sent as multipart/form-data so an optional photo can
  /// be attached. Returns the decoded JSON body (same convention as the app:
  /// HTTP 200 with a `status` flag).
  Future<dynamic> updateProfile(
    Map<String, String> fields, {
    required String apiKey,
    String? imagePath,
  }) async {
    final uri = Uri.parse(
        ApiEndPoints.baseUrl + ApiEndPoints.moreScreenEndPoints.profileUpdateUrl);

    final request = http.MultipartRequest('POST', uri);
    request.headers['x-client-getgabs'] = apiKey;
    request.fields.addAll(fields);

    if (imagePath != null && imagePath.isNotEmpty) {
      request.files
          .add(await http.MultipartFile.fromPath('profile_image', imagePath));
    }

    try {
      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final body = await streamed.stream.bytesToString();
      if (kDebugMode) {
        debugPrint('profile/update ${streamed.statusCode}: $body');
      }
      // The header check is a real 400; everything else is 200 with a flag.
      if (streamed.statusCode == 400) {
        return {'status': false, 'message': 'invalid headers'};
      }
      return jsonDecode(body);
    } catch (e) {
      debugPrint('❌ updateProfile error: $e');
      return {'status': false, 'message': 'Something went wrong. Try again.'};
    }
  }
}
