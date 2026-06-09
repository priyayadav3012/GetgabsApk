// import 'package:flutter/material.dart';
import 'package:flutter/material.dart';



class ReplyBaseMessageUi extends StatelessWidget {
  final Widget child;
  
  final Size mediaQuery;
  
  final bool isInTemplate; // New parameter for template-specific styling

  const ReplyBaseMessageUi({super.key, 
    required this.child,
   
    required this.mediaQuery,
    
    this.isInTemplate = false, // Default to false
  });

 

  @override
  Widget build(BuildContext context) {
    return Align(
     
      
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15.0),
        child: Container(
          constraints: BoxConstraints(
            maxWidth:
                mediaQuery.width * 0.6, 
                // maxHeight: mediaQuery.height*0.6
                // Maximum width of the message bubble
             
          ),
          // margin: EdgeInsets.only(
          //   top: mediaQuery.height * 0.025,
          //   bottom: mediaQuery.height * 0.01,
           
          // ),
          // padding: EdgeInsets.symmetric(
          //   horizontal: mediaQuery.width * 0.03,
          //   vertical: mediaQuery.height * 0.011,
          // ),
          
          
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // PopupMenuButton<String>(
              //   icon: Icon(Icons.arrow_drop_down_outlined, size: 20),
              //   offset: const Offset(50, 0),
              //   onSelected: (String value) {
              //     if (value == 'reply') {
              //       print("reply this message4");
              //     } else if (value == 'forward') {

              //     }
              //   },
              //   itemBuilder: (BuildContext context) {
              //     return [
              //       PopupMenuItem<String>(
              //         value: 'reply',
              //         child: Row(
              //           children: [
              //             Icon(Icons.reply, size: 16),
              //             SizedBox(width: 1),
              //             Text('Reply'),
              //           ],
              //         ),
              //       ),
              //       PopupMenuItem<String>(
              //         value: 'forward',
              //         child: Row(
              //           children: [
              //             Icon(Icons.forward, size: 16),
              //             SizedBox(width: 1),
              //             Text('Forward'),
              //           ],
              //         ),
              //       ),
              //     ];
              //   },
              // ),
              child,
             
              SizedBox(height: mediaQuery.height * 0.00),
              // Row(
              //   mainAxisSize: MainAxisSize.min,
              //   children: [
                 
              //     SizedBox(width: mediaQuery.width * 0.01),
                 
              //   ],
              // ), // Text(
              //   formattedTime,
              //   style: const TextStyle(fontSize: 10, color: Colors.grey),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}



