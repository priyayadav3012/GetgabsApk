import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getgabs/domain/controllers/auth/login_with_email/login_with_email_controller.dart';
import 'package:getgabs/domain/controllers/dashboard/dashboard_controller.dart';
import 'package:getgabs/ui/pages/dashboard/chats/rolling_over_chats.dart/rolling_over_list_tile.dart';
import 'package:getgabs/ui/themes/themes.dart';

class RollingOverChats extends StatelessWidget {
  RollingOverChats({super.key});
  final DashboardController dashboardController = Get.put(DashboardController());
bool get _isMessagedly => LoginWithEmailController.currentFlavor == 'messagedly';
bool get _isScalewiz => LoginWithEmailController.currentFlavor == 'scalewiz';
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return RefreshIndicator(
        onRefresh: () async {
          await dashboardController.refreshRollingOverChatList(increment: 'replace',);
          // await dashboardController.refreshRollingOverChatList();
        },
        child: dashboardController.isInActiveApiInCall.value
            ? const Center(child: CircularProgressIndicator())
            : dashboardController.rollingOverProfileDetailsList.isNotEmpty
                ? ListView.builder(
                    itemCount: dashboardController
                        .rollingOverProfileDetailsList.length,
                    controller: dashboardController.rollingOverScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemBuilder: (context, index) {
                      final chatItem = dashboardController
                          .rollingOverProfileDetailsList[index];
                      return Column(
                        children: [
                          // const Divider(
                          //   color: AppTheme.boarderColor,
                          // ),
                          RollingOverListTile(rollingOverChatModel: chatItem),
                        ],
                      );
                    },
                  )
                : noDataFound(),
      );
    });
  }

  Widget noDataFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          //  Icon(
          //   Icons.hourglass_empty_outlined,
          //   size: 64,
          //   color: Colors.grey,
          // ),
          // SizedBox(height: mediaQuery.height*0.04),
          //       Container(
          //   width: 80,
          //   height: 80,
          //   child: Image.asset(ImageAssets.getGabsLogoPng,
          //     // color: Colors.grey, // This will apply a color filter to the image
          //     colorBlendMode: BlendMode.srcIn, // Ensure the color is applied correctly
          //   ),
          // ),

          const Text(
            "No Chats found!",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          Material(
            borderRadius: BorderRadius.circular(5),
            elevation: 0,
           color: _isMessagedly
                ? const Color(0xff4242D4)
                : _isScalewiz
                    ? const Color(0xff17A398)
                    : Colors.green,
            child: InkWell(
              onTap: () {
                dashboardController.refreshRollingOverChatList(
                    increment: 'replace');

                // homeController.isLoading.value = true;
                // homeController.leadList.clear();
                // homeController.page.value = 1;
                // homeController.leadListApi();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: const Text(
                  "Refresh",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
