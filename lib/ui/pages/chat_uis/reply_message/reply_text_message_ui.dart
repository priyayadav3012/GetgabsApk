import 'package:flutter/material.dart';
import 'package:getgabs/ui/pages/chat_uis/reply_message/reply_base_message_ui.dart';




class ReplyTextMessageUi extends StatelessWidget {
  final String text;
  final Size mediaQuery;


  const ReplyTextMessageUi({super.key, 
    required this.text,
    required this.mediaQuery,
     
  });

  @override
  Widget build(BuildContext context) {
    return Text(text);
    
    
    ReplyBaseMessageUi(
      
      mediaQuery: mediaQuery,
           
      child: Text(
        text,
        softWrap: true, // Allows text to wrap within its container
        overflow: TextOverflow.visible, // Ensures text is not clipped
      ),
    );
  }
}
