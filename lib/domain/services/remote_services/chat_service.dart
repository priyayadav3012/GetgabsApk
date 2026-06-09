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
}
// moved shortMessageListService inside ChatServices to use _apiService


//------------------------------------template-messages-------------------------------------------------

