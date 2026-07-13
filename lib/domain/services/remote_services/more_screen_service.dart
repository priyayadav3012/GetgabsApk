import 'package:getgabs/domain/network/network_api_services.dart';
import 'package:http/http.dart' as http;

import '../../end_points/api_end_points.dart';

class MoreScreenService {
  var client = http.Client();

  final _apiService = NetworkApiServices();

  Future<dynamic> logoutService(var data, {var headers}) async {
    dynamic response = _apiService.postApi(
        data,
        ApiEndPoints.baseUrl +
            ApiEndPoints.moreScreenEndPoints.logoutUrl,
        headers: headers);
    return response;
  }

}