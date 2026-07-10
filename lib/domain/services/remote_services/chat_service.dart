import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:getgabs/domain/network/network_api_services.dart';
import 'package:http/http.dart' as http;

import '../../end_points/api_end_points.dart';

class ChatServices {
  var client = http.Client();

  final _apiService = NetworkApiServices();

  Future<dynamic> activeChatList(var data, {var headers}) async {
    dynamic response = _apiService.postApi(
        data,
        ApiEndPoints.baseUrl +
            ApiEndPoints.dashboardEndPoints.activeChatListUrl,
        headers: headers);
    return response;
  }

  Future<dynamic> loadChats(var data, {var headers}) async {
    dynamic response = _apiService.postApi(
        data, ApiEndPoints.baseUrl + ApiEndPoints.chatEndPoints.chatList,
        headers: headers);
    return response;
  }

  Future<dynamic>sendMessageService(var data, {var headers}) async {
    dynamic response = _apiService.postApi(
        data, ApiEndPoints.baseUrl + ApiEndPoints.chatEndPoints.sendMessageUrl,
        headers: headers);

    return response;
  }

  Future<dynamic>sendHelloWorldTemplateService(var data, {var headers}) async {
    dynamic response = _apiService.postApi(
        data,
        ApiEndPoints.baseUrl +
            ApiEndPoints.chatEndPoints.sendHelloWorldTemplateUrl,
        headers: headers);
    return response;
  }
  Future<dynamic> shortMessageListService(var data, {var headers}) async {
  dynamic response = _apiService.postApi(
    data,
    ApiEndPoints.baseUrl + ApiEndPoints.chatEndPoints.shortMessageList,
    headers: headers,
  );
  return response;
}
Future<dynamic> sendShortMessageService(var data, {var headers}) async {
  dynamic response = _apiService.postApi(
    data,
    ApiEndPoints.baseUrl + ApiEndPoints.chatEndPoints.sendShortMessage,
    headers: headers,
  );
  return response;
}
  Future<dynamic>searchCustomer(var data, {var headers}) async {
    dynamic response = _apiService.postApi(
        data, ApiEndPoints.baseUrl + ApiEndPoints.chatEndPoints.searchCustomer,
        headers: headers);
    return response;
  }

//------------------------------------template-messages-------------------------------------------------
  Future<dynamic>fetchTemplatesService(var data, {var headers}) async {
    dynamic response = _apiService.postApi(data,
        ApiEndPoints.baseUrl + ApiEndPoints.chatEndPoints.fetchTemplateNamesUrl,
        headers: headers);
    return response;
  }

  Future<dynamic>fetchTemplateStructureService(var data, {var headers}) async {
    dynamic response = _apiService.postApi(
        data,
        ApiEndPoints.baseUrl +
            ApiEndPoints.chatEndPoints.fetchTemplateStructureUrl,
        headers: headers);
    return response;
  }

  Future<dynamic>fetchMessageTemplateJsonService(var data,
      {var headers}) async {
    dynamic response = _apiService.postApi(
        data,
        ApiEndPoints.baseUrl +
            ApiEndPoints.chatEndPoints.fetchMessageTemplateJsonUrl,
        headers: headers);
    return response;
  }
Future<dynamic> toggleHandoffService(var data, {var headers}) async {
    dynamic response = _apiService.postApi(
        data,
        ApiEndPoints.baseUrl +
            ApiEndPoints.chatEndPoints.toggleHandoffUrl,
        headers: headers);
    return response;
  }

  // ✅ /partners/ endpoints are multipart/form-data (confirmed via curl
  // --form examples), not JSON — calling http directly via MultipartRequest
  // instead of NetworkApiServices.postApi(), which only sends JSON and whose
  // returnResponse() throws a bare InvalidUrlException on 400/302, discarding
  // response.body and hiding the backend's actual validation message.
  Future<dynamic> _postPartnersMultipart(
      String url, Map<String, String> fields) async {
    final request = http.MultipartRequest('POST', Uri.parse(url))
      ..fields.addAll(fields);
    final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint('📡 $url → [${response.statusCode}] ${response.body}');

    try {
      return jsonDecode(response.body);
    } catch (_) {
      return {
        'status': false,
        'message': 'Server error (${response.statusCode}): ${response.body}'
      };
    }
  }

  // Exchanges the WhatsApp Business api_key for a short-lived bearer/session
  // token used to authenticate every other /partners/ call.
  Future<dynamic> getSessionTokenService(Map<String, String> fields) async {
    return _postPartnersMultipart(
        ApiEndPoints.partnersEndPoints.getSessionTokenUrl, fields);
  }

  Future<dynamic> addCustomerService(Map<String, String> fields) async {
    return _postPartnersMultipart(
        ApiEndPoints.partnersEndPoints.addCustomerUrl, fields);
  }
}
// moved shortMessageListService inside ChatServices to use _apiService


//------------------------------------template-messages-------------------------------------------------

