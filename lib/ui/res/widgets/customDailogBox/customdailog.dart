import 'package:flutter/material.dart';
import 'package:getgabs/ui/themes/themes.dart';

class CustomDialog extends StatelessWidget {
  final String title;
  final String yesButtonText;
  final String noButtonText;
  final VoidCallback onYesPressed;
  final VoidCallback onNoPressed;

  const CustomDialog({
    super.key,
    required this.title,
    required this.yesButtonText,
    required this.noButtonText,
    required this.onYesPressed,
    required this.onNoPressed,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
           
        ),
              elevation: 12.0, 
      
        title: Text(
          title,
          style: const TextStyle(fontSize: 12),
        ),
        titlePadding: EdgeInsets.symmetric(
          vertical: screenHeight * 0.03,
          horizontal: screenWidth * 0.10,
        ),
        contentPadding: EdgeInsets.zero,
        content: const Divider(height: 0),
        actions: [
         
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextButton(
                  onPressed: onYesPressed,
                  child: Text(
                    yesButtonText,
                    style: TextStyle(
                      color: AppTheme.appThemeColor,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              Container(
                height: 50,
                width: 1.0,
                color: Colors.grey,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextButton(
                  onPressed: onNoPressed,
                  child: Text(
                    noButtonText,
                    style: TextStyle(
                      color: AppTheme.appThemeColor,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
