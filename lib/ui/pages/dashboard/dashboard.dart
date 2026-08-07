import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:getgabs/domain/controllers/dashboard/dashboard_controller.dart';
import 'package:getgabs/ui/pages/dashboard/call_logs/call_logs_screen.dart';
import 'package:getgabs/ui/pages/dashboard/chats/chats.dart';
import 'package:getgabs/ui/pages/dashboard/more/more_screen.dart';
import 'package:getgabs/ui/res/assets/image_assets.dart';
import 'package:getgabs/ui/themes/themes.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize call listener when dashboard is built
    final controller = Get.find<DashboardController>();
    controller.initCallListener();
    
    return GetBuilder<DashboardController>(
      builder: (controller) => Scaffold(
        body: IndexedStack(
          index: controller.tabIndex,
          children: [
            ChatsScreen(),
            const CallLogsScreen(),
            const MoreScreen()
          ],
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.symmetric(vertical: 0.0),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color.fromARGB(255, 143, 142, 142), width: 0.2),
              ),
            ),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              // selectedItemColor: AppTheme.blackColor,
              selectedItemColor: AppTheme.authButtonColor,
              unselectedItemColor: const Color(0xff3E2323),
              currentIndex: controller.tabIndex,
              // selectedLabelStyle: const TextStyle(fontSize: 11),
              unselectedLabelStyle: const TextStyle(fontSize: 11),
              onTap: (val) {
                controller.updateIndex(val);
              },
              items: [
                BottomNavigationBarItem(
                  icon: SvgPicture.asset(ImageAssets.messageChatIcon, height: 24, width: 24,),
                  label: 'Chats',
                  activeIcon: SvgPicture.asset(ImageAssets.messageChatIcon, height: 24, width: 24, color: AppTheme.authButtonColor,),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.call, size: 24),
                  label: 'Call Logs',
                  activeIcon: Icon(Icons.call, size: 24, color: AppTheme.authButtonColor),
                ),
                BottomNavigationBarItem(
                  icon: SvgPicture.asset(ImageAssets.menuIcon, height: 24, width: 24,),
                  label: 'More',
                  activeIcon: SvgPicture.asset(ImageAssets.menuIcon, height: 24, width: 24, color: AppTheme.authButtonColor,),
                ),
              ],
              // items: [
              //   BottomNavigationBarItem(
              //     icon: Image.asset(ImageAssets.chatPng),
              //     label: 'Chat',
              //     activeIcon: Image.asset(ImageAssets.chatPng),
              //   ),
              //   BottomNavigationBarItem(
              //     icon: Image.asset(ImageAssets.morePng),
              //     label: 'More',
              //     activeIcon: Image.asset(ImageAssets.morePng),
              //   ),
              // ],
            ),
          ),
        ),
      ),
    );
  }
}