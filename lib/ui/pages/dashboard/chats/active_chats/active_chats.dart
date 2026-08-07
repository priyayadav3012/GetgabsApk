import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getgabs/domain/controllers/auth/login_with_email/login_with_email_controller.dart';
import 'package:getgabs/domain/controllers/dashboard/dashboard_controller.dart';
import 'package:getgabs/ui/pages/dashboard/chats/active_chats/active_chat_list_tile.dart';
import 'package:getgabs/ui/res/widgets/skeleton_loaders.dart';
import 'package:getgabs/ui/themes/themes.dart';

class ActiveChats extends StatelessWidget {
  ActiveChats({super.key});

  final DashboardController dashboardController =
      Get.find<DashboardController>();
bool get _isMessagedly => LoginWithEmailController.currentFlavorNormalized == 'messagedly';
bool get _isScalewiz => LoginWithEmailController.currentFlavorNormalized == 'scalewiz';
  @override
  Widget build(BuildContext context) {
    return Obx(() {

      /// ✅ Show loader ONLY when loading AND list is empty
      if (dashboardController.isActiveApiInCall.value) {
        return const ChatListSkeleton();
      }

      /// ✅ Main content
      return RefreshIndicator(
        onRefresh: () async {
          await dashboardController.refreshActiveChatList(
            increment: 'replace',
          );
        },
        child: dashboardController.activeProfileDetailsList.isNotEmpty
            ? ListView.builder(
                controller: dashboardController.dashScrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: dashboardController.activeProfileDetailsList.length,
                itemBuilder: (context, index) {

                  final profileDetail =
                      dashboardController.activeProfileDetailsList[index];

                  return ActiveChatListTile(
                    profile: profileDetail,
                  );
                },
              )
            : noDataFound(),
      );
    });
    // return Obx(() {
    //   return RefreshIndicator(
    //     onRefresh: () async {
    //       await dashboardController.refreshActiveChatList();
    //     },
    //     child: dashboardController.isApiCallInProgress.value  ? const Center(child: CircularProgressIndicator()):
        
    //     dashboardController.activeProfileDetailsList.isNotEmpty
    //         ? ListView.builder(
    //           controller: dashboardController.dashScrollController,
    //           physics: const AlwaysScrollableScrollPhysics(),
    //             itemCount: dashboardController.activeProfileDetailsList.length,
    //             itemBuilder: (context, index) {
    //               final profileDetail = dashboardController.activeProfileDetailsList[index];
    //               return Column(
    //                 children: [
    //                   // Container(
    //                   //   padding: EdgeInsets.symmetric(horizontal: 16.0),
    //                   //   margin: EdgeInsets.symmetric(horizontal: 16.0),
    //                   //   child: Divider(color: AppTheme.unreadMessagesColor, thickness: 0.5,),
    //                   // ),
    //                   ActiveChatListTile(profile: profileDetail),
    //                 ],
    //               );
    //             },
    //           )
    //         : noDataFound(),
    //   );
    // });
    
    // Obx(() {
    //   if (dashboardController.activeProfileDetailsList.isNotEmpty) {
    //     return ListView.builder(
    //       itemCount: dashboardController.activeProfileDetailsList.length,
    //       itemBuilder: (context, index) {
    //         final profileDetail =
    //             dashboardController.activeProfileDetailsList[index];
    //         return Column(
    //           children: [
    //             const Divider(
    //               color: AppTheme.boarderColor,
    //             ),
    //             ActiveChatListTile(profile: profileDetail)
    //           ],
    //         );
    //       },
    //     );
    //   } else {
    //     return noDataFound();
    //   }
    // });
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
             dashboardController.refreshActiveChatList(increment: 'replace');
                // homeController.isLoading.value = true;
                // homeController.leadList.clear();
                // homeController.page.value = 1;
                // homeController.leadListApi();
                // print("fdlskjflksdf");
                // dashboardController.activeChatListApi(increment: 'replace');
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
