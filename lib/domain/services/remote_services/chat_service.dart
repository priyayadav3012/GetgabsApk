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
Future<dynamic> voiceCallLogsService(var data, {var headers}) async {
  dynamic response = _apiService.postApi(
    data,
    ApiEndPoints.baseUrl + ApiEndPoints.chatEndPoints.voiceCallLogs,
    headers: headers,
  );
  return response;
}
Future<dynamic> sendReplyChatService(var data, {var headers}) async {
  dynamic response = _apiService.postApi(
    data,
    ApiEndPoints.baseUrl + ApiEndPoints.chatEndPoints.sendReplyChat,
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
  //
  // [label] tags every request/response pair in the console with the
  // calling method's name (e.g. "addCoAssign") so a run's logs can be
  // grep'd/filtered per-API when tracing down a failure — mirror the same
  // fields against postman/assign_chat_apis.postman_collection.json to
  // compare app vs. Postman side by side.
  Future<dynamic> _postPartnersMultipart(
      String url, Map<String, String> fields,
      {String label = ''}) async {
    debugPrint('🔎 [$label] → POST $url');
    debugPrint('🔎 [$label]   fields: $fields');
    final request = http.MultipartRequest('POST', Uri.parse(url))
      ..fields.addAll(fields);
    final streamedResponse = await request.send().timeout(const Duration(seconds: 60));
    final response = await http.Response.fromStream(streamedResponse);

    debugPrint('🔎 [$label] ← [${response.statusCode}] ${response.body}');

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
        ApiEndPoints.partnersEndPoints.getSessionTokenUrl, fields,
        label: 'getSessionToken');
  }

  Future<dynamic> addCustomerService(Map<String, String> fields) async {
    return _postPartnersMultipart(
        ApiEndPoints.partnersEndPoints.addCustomerUrl, fields,
        label: 'addCustomer');
  }

  // Read-style /partners/ calls (list/fetch) — sent as GET with the bearer
  // token as a query param, mirroring how _postPartnersMultipart sends it as
  // a form field for writes. See _postPartnersMultipart's doc comment for
  // what [label] is for.
  Future<dynamic> _getPartnersJson(
      String url, Map<String, String> queryParams,
      {String label = ''}) async {
    final uri = Uri.parse(url).replace(queryParameters: queryParams);
    debugPrint('🔎 [$label] → GET $uri');
    try {
      final response =
          await http.get(uri).timeout(const Duration(seconds: 60));
      debugPrint('🔎 [$label] ← [${response.statusCode}] ${response.body}');
      return jsonDecode(response.body);
    } catch (e) {
      debugPrint('🔎 [$label] ✗ error: $e');
      return {'status': false, 'message': 'Server error: $e'};
    }
  }

  Future<dynamic> fetchExecutiveListService(String token) async {
    return _getPartnersJson(
        ApiEndPoints.partnersEndPoints.fetchExecutiveListUrl, {'token': token},
        label: 'fetchExecutiveList');
  }

  Future<dynamic> listTeamsService(String token) async {
    return _getPartnersJson(
        ApiEndPoints.partnersEndPoints.listTeamsUrl, {'token': token},
        label: 'listTeams');
  }

  Future<dynamic> getCoAssigneesService({
    required String customerKey,
    required String token,
  }) async {
    return _getPartnersJson(ApiEndPoints.partnersEndPoints.getCoAssigneesUrl,
        {'customerKey': customerKey, 'token': token},
        label: 'getCoAssignees');
  }

  // Confirmed GET (not the usual /partners/ multipart-POST pattern) —
  // same as updatelastshortsummery.
  Future<dynamic> addCoAssignService(Map<String, String> fields) async {
    return _getPartnersJson(
        ApiEndPoints.partnersEndPoints.addCoAssignUrl, fields,
        label: 'addCoAssign');
  }

  // Confirmed GET (not the usual /partners/ multipart-POST pattern) —
  // Mode 3 (Assign to Sub-user) of updatelastshortsummery.
  Future<dynamic> updateLastSummaryAssignService(
      Map<String, String> fields) async {
    return _getPartnersJson(
        ApiEndPoints.partnersEndPoints.updateLastSummaryUrl, fields,
        label: 'updateLastSummaryAssign');
  }

  Future<dynamic> assignTeamService(Map<String, String> fields) async {
    return _postPartnersMultipart(
        ApiEndPoints.partnersEndPoints.assignTeamUrl, fields,
        label: 'assignTeam');
  }
}
// moved shortMessageListService inside ChatServices to use _apiService


//------------------------------------template-messages-------------------------------------------------

