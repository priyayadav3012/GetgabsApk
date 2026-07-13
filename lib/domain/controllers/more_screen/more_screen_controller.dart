import 'package:get/get.dart';
import 'package:getgabs/domain/services/remote_services/more_screen_service.dart';

import '../../../data/get_storage/get_storage.dart';

class MoreScreenController extends GetxController{
    GetStorageUserData userData = GetStorageUserData();
    MoreScreenService moreScreenService = MoreScreenService();
  Future<void> logoutApi() async {
    try {
      final id = await userData.getLoggedInUserId();


      Map data = {
        "id": id,

      };
      Map<String, String> headers = {
        "Content-Type": "application/json"
      };

      // configLoading();
      // showLoading();
      moreScreenService.logoutService(data, headers: headers).then((value) {
        print('2342342342343klkljlkjlkjlkjlkjlkjlkjlk');
        if (value['status']) {
          // EasyLoading.dismiss();
          List<dynamic> chatsList = value['message']['data']['data'] ?? [];
          // messageChatList.assignAll(
          // chatsList.map((datas) => Message.fromJson(datas)).toList());

          // if (from == 'inside') {
          //   messageChatList.addAll(
          //       chatsList.map((datas) => Message.fromJson(datas)).toList());
          // } else {
          //   messageChatList.assignAll(
          //       chatsList.map((datas) => Message.fromJson(datas)).toList());
          // }
          // currentPage++;
        } else {
          // print('2342342342343klkljlkjlkjlkjlkjlkjlkjl');
          // EasyLoading.dismiss();
        }
      }).onError((error, stackTrace) {
        print(error);
        print(stackTrace);
      }).whenComplete(() {
        //isApiCallInProgress = false;
      });
    } catch (error, stackTrace) {
      print('Error: $error');
      print('Stack Trace: $stackTrace');
      // EasyLoading.dismiss();
    }
  }

}