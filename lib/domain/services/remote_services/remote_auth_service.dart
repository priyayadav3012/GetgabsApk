
import 'dart:convert';

import 'package:getgabs/domain/end_points/api_end_points.dart';
import 'package:getgabs/domain/network/network_api_services.dart';
import 'package:http/http.dart' as http;

class RemoteAuthService {
  var client = http.Client();

  final _apiService = NetworkApiServices();

  Future<dynamic> loginWithEmailApiService(var data) async {
    dynamic response = _apiService.postApi(data, ApiEndPoints.baseUrl+ApiEndPoints.authEndpoints.loginWithEmailUrl);
    return response;
  }
 Future<dynamic> saveVoipTokenService(var data, String tokenKey) async {
    var url = Uri.parse("${ApiEndPoints.baseUrl}${ApiEndPoints.authEndpoints.saveVoipToken}".trim());
    
    try {
      print("Hitting direct HTTP with custom secure headers...");
      
      var response = await http.post(
        url,
        headers: {
          "X-Client-GetGabs": tokenKey, // 👈 FIXED: Ab dynamic key header mein perfect jayegi
          "Content-Type":     "application/json",
          "Accept":           "application/json",
        },
        body: jsonEncode(data),
      );
      
      print("Direct HTTP Response Code: ${response.statusCode}");
      print("Direct HTTP Response Body: ${response.body}");
      
      return jsonDecode(response.body);
    } catch (e) {
      print("Direct HTTP Exception: $e");
      return {"status": false, "message": e.toString()};
    }
  }



}
