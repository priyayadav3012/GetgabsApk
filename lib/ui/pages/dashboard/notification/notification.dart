import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getgabs/domain/controllers/dashboard/dashboard_controller.dart';
import 'package:getgabs/ui/res/assets/image_assets.dart';

class NotificationScreen extends StatelessWidget {
  NotificationScreen({super.key});

  final DashboardController dashboardController =
      Get.put(DashboardController());

  @override
  Widget build(BuildContext context) {
    var mediaQuery = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        elevation: 6,
        shadowColor: Colors.black,
        backgroundColor: Colors.white,
        title: const Text('Notifications (5)'),
        actions: [
          IconButton(
            icon: Image.asset(ImageAssets.calendarPng),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                WidgetsBinding.instance.addPostFrameCallback((_) {});
              },
              child: // Obx(() {
                  Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Today", textAlign: TextAlign.start),
                  const Divider(),
                  Expanded(child: buildChatList()),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  var chatList = <ChatItem>[
    ChatItem(
        name: "Dimpal",
        message: "Need a laptop for graphic design.....",
        time: "11:00",
        unreadMessages: 1),
    ChatItem(
        name: "Sangita",
        message: "Need a laptop for graphic design.....",
        time: "11:00",
        unreadMessages: 1),
    ChatItem(
        name: "kripal",
        message: "Need a laptop for graphic design.....",
        time: "11:00",
        unreadMessages: 1),
    ChatItem(
        name: "Irfan",
        message: "Need a laptop for graphic design.....",
        time: "11:00",
        unreadMessages: 1),
    // Add more items as needed
  ].obs;
  Widget buildChatList() {
    return Obx(() {
      return ListView.builder(
        itemCount:chatList.length,
        itemBuilder: (context, index) {
          final chatItem = chatList[index];
          return Column(
            children: [
              // Divider(
              //   color: AppTheme.boarderColor,
              // ),
              ListTile(
                minTileHeight: 20,
                leading: CircleAvatar(
                  backgroundImage: AssetImage(ImageAssets
                      .getGabsLogoPng), // Replace with your image asset
                ),
                title: Text(
                  chatItem.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  chatItem.message,
                  style: const TextStyle(
                    fontSize: 11,
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(chatItem.time),
                    if (chatItem.unreadMessages > 0)
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.green,
                        child: Text(
                          chatItem.unreadMessages.toString(),
                          style: const TextStyle(fontSize: 12, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(),
            ],
          );
        },
      );
    });
  }
}
class ChatItem {
  final String name;
  final String message;
  final String time;
  final int unreadMessages;

  ChatItem({
    required this.name,
    required this.message,
    required this.time,
    required this.unreadMessages,
  });
}
