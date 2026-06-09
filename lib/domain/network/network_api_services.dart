import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:getgabs/domain/exceptions/app_exceptions.dart';
import 'package:getgabs/domain/network/base_api_services.dart';
import 'package:http/http.dart' as http;

class NetworkApiServices extends BaseApiServices {
  @override
  Future<dynamic> getApi(String url) async {
    if (kDebugMode) {
      print(url);
    }
    dynamic responseJson;
    try {
      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
      responseJson = returnResponse(response);
    } on SocketException {
      throw InternetException('');
    } on RequestTimeoutException {
      throw RequestTimeoutException('');
    }
    return responseJson;
  }

  @override
  Future<dynamic> postApi(dynamic data, String url,
      {Map<String,String>? headers}) async {
    if (kDebugMode) {
      print(url);
      print(data);
    }
    dynamic responseJson;
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: headers ?? {'Content-Type': 'application/json'},
            body: jsonEncode(data),
          )
          .timeout(const Duration(seconds: 60));
      responseJson = returnResponse(response);
    } on SocketException {
      throw InternetException('');
    } on RequestTimeoutException {
      throw RequestTimeoutException('');
    }

    return responseJson;
  }

  dynamic returnResponse(http.Response response) {
    switch (response.statusCode) {
      case 200:
        dynamic responseJson = jsonDecode(response.body);
        // if (responseJson['status']) {
        //   print(responseJson);
        // } else {
        //   print(responseJson);
        // }
        return responseJson;

      case 302:
      case 400:
        throw InvalidUrlException;
      default:
        throw FetchDataException(
            'Error occuring while communicating with server ${jsonDecode(response.body)}');
    }
  }
}
  // Future<dynamic> multipartPostRequest(String url, Map<String, dynamic> fields) async {
  //   try {
  //     var uri = Uri.parse(url);
  //     var request = http.MultipartRequest('POST', uri);

  //     fields.forEach((key, value) {
  //       if (value != null) {
  //         request.fields[key] = value.toString();
  //       }
  //     });

   
  //    final response = await request.send();
  //     dynamic responseJson =  returnMultipartResponse(response);
  //     return responseJson;

  //   }  on SocketException {
  //     throw InternetException('');
  //   } on RequestTimeoutException {
  //     throw RequestTimeoutException('');
  //   }
  // }


  // dynamic returnMultipartResponse(response) async {
  //   switch (response.statusCode) {
  //     case 200:
  //         final bodyStream = response.stream.transform(utf8.decoder);
  //       final jsonString = await bodyStream.join();
  //       final responseJson = jsonDecode(jsonString);
  //       if (responseJson['status'] == '0') {
  //         print(responseJson);
  //       } else {
  //         print(responseJson);
  //       }
  //       return responseJson;

  //     case 302:
  //     case 400:
  //       throw InvalidUrlException;
  //     default:
  //       throw FetchDataException(
  //           'Error occuring while communicating with server ${response.statusCode}');
  //   }
  // }
