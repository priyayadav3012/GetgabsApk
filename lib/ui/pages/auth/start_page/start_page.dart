import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:getgabs/routes/app_route.dart';
import 'package:getgabs/ui/res/assets/image_assets.dart';
import 'package:getgabs/ui/res/widgets/reusable_widgets.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});
  @override
  Widget build(BuildContext context) {
    var mediaQuery = MediaQuery.of(context).size;
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Center(
            child: Column(
              children: [
                SizedBox(height: mediaQuery.height * 0.01),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: mediaQuery.width * 0.07),
                  child: SvgPicture.asset(ImageAssets.startScreenImageSvg),
                ),
                SizedBox(height: mediaQuery.height * 0.03),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: mediaQuery.width * 0.07),
                  child: const AutoSizeText(
                    'Experience the power of sales targeted customizable campaign',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 18.0, fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(height: mediaQuery.height * 0.03),
                ReusableWidgets.authButton(
                    name: 'Get started',
                    onPressed: () {Get.toNamed(AppRoute.loginWithEmail);},
                    mediaQuery: mediaQuery)
              ],
            ),
          ),
        ),
      ),
    );
  }
}
