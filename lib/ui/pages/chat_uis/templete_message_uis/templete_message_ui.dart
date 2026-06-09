import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getgabs/ui/pages/chat_uis/vide_message_uis/video_message_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../base_message_ui.dart';
import 'dart:convert';

class TempleteMessageUi extends StatelessWidget {
  final String? templateData;
  final String messageText;
  final bool isSentByMe;
  final DateTime createdAt;
  final Size mediaQuery;
  final String deliveryStatus;
  final String messageType;
   final String? senderName;
 
  const TempleteMessageUi({
    super.key,
    required this.templateData,
    required this.messageText,
    required this.isSentByMe,
    required this.createdAt,
    required this.mediaQuery,
    required this.deliveryStatus,
    required this.messageType, 
    required this.senderName,
  });
  


  String replaceTemplateVariables(String text, List<dynamic> parameters) {
    for (var i = 0; i < parameters.length; i++) {
      final placeholder = '{{${i + 1}}}';
      final value = parameters[i]['text'] != null
          ? parameters[i]['text'].toString()
          : ''; // Handle null values
      text = text.replaceAll(placeholder, value);
    }
    return text;
  }
  bool isJson(String str) {
  try {
    jsonDecode(str);
    return true;
  } catch (e) {
    return false;
  }
}
      String replaceDynamicVariables(String text, Map<String, String> values) {
  values.forEach((key, value) {
    text = text.replaceAll('{$key}', value);
  });
  return text;
}
   
  Map<String, dynamic> parseTemplateData() {
    String headerText = '';
    String bodyText = '';
    String footerText = '';
    String imageUrl = '';
    String videoUrl = '';
    List<Map<String, String>> buttonsList = [];
    Map<String, dynamic> interactiveMessage = {};

//  print("33333333333333333333333333");

    try {
      if (templateData != null &&
          templateData!.isNotEmpty &&
          messageText.isNotEmpty) {
        final Map<String, dynamic> templateDataMap = jsonDecode(templateData!);
        print(templateDataMap);
        if (templateDataMap.containsKey('data')) {
          if (templateDataMap['data'].isNotEmpty &&
              templateDataMap['data'][0].containsKey('components')) {
            final List<dynamic> components =
                templateDataMap['data'][0]['components'];

            for (var component in components) {
              if (component['type'] == 'HEADER') {
                if (component.containsKey('text')) {
                  headerText = component['text'];
                }
                if (component.containsKey('format') &&
                    component['format'] == 'IMAGE') {
                  imageUrl = component['example']['header_handle'][0];
                } else if (component.containsKey('format') &&
                    component['format'] == 'VIDEO') {
                  videoUrl = component['example']['header_handle'][0];
                }
              } else if (component['type'] == 'BODY' &&
                  component.containsKey('text')) {
                bodyText = component['text'];
              } else if (component['type'] == 'FOOTER' &&
                  component.containsKey('text')) {
                footerText = component['text'];
              } else if (component['type'] == 'BUTTONS' &&
                  component.containsKey('buttons')) {
                for (var buttons in component['buttons']) {
                  final buttonText = buttons['text'] ?? "";
                  final buttonType = buttons['type'] ?? "";
                  final buttonUrl = buttonType == 'URL' ? buttons['url'] : "";

                  buttonsList.add({
                    'text': buttonText,
                    'type': buttonType,
                    'url': buttonUrl
                  });
                }
              }
            }
          }
        } else if (templateData == null) {
          print('Error: templateData does not contain expected structure.');
        }
      }
   
      
      if (messageText.isNotEmpty && isJson(messageText)) {
       Map<String, dynamic> messageTextData = {};

if (isJson(messageText)) {
  messageTextData = jsonDecode(messageText);
} else {
  print("messageText is plain text: $messageText");
}

        if (messageTextData.containsKey('template') &&
            messageTextData['template'].containsKey('components')) {
          final List<dynamic> templateComponents =
              messageTextData['template']['components'];

          for (var component in templateComponents) {
            if (component.containsKey('parameters')) {
              final List<dynamic> parameters = component['parameters'] ?? [];

              if (component['type'] != null) {
                final type =
                    (component['type'] as String?)?.toUpperCase() ?? '';

                if (type == 'HEADER') {
                  headerText = replaceTemplateVariables(headerText, parameters);
                  if (parameters.isNotEmpty) {
                    final parameterType = parameters[0]['type'];
                    if (parameterType == 'IMAGE') {
                      imageUrl = parameters[0]['image']['link'] ?? '';
                    } else if (parameterType == 'VIDEO') {
                      videoUrl = parameters[0]['video']['link'] ?? '';
                    }
                  }
                } else if (type == 'BODY') {
                  bodyText = replaceTemplateVariables(bodyText, parameters);
                } else if (type == 'FOOTER') {
                  footerText = replaceTemplateVariables(footerText, parameters);
                } // else if(type =='BUTTONS'){
                //   buttonsList = replaceTemplateVariables(buttonsList, parameters) as List<Map<String, String>>;
                // }
                else if (type == 'BUTTONS') {
                  // buttonsList = replaceTemplateVariables(buttonsList, parameters);
                  //     for(var buttons in component['buttons']){
                  //   final buttonText = buttons['text']?? "";
                  //   final buttonType = buttons['type']??"";
                  //   final buttonUrl = buttonType == 'URL' ? buttons['url']:"";

                  // }
                }
              }
            }
          }
        } else if (messageTextData.containsKey('interactive')) {
          // print("777777777777777777777777777777777777777");
          final Map<String, dynamic> interactiveData = jsonDecode(messageText);
          final Map<String, dynamic>? interactive =
              interactiveData['interactive'];

          if (interactiveData.isNotEmpty) {
            interactiveMessage = interactive!;
          }
        } else {
          print(
              'Error: messageText does not contain expected template structure.');
          print(messageText);
        }
      }
    } catch (e) {
      print('Error parsing template data: $e');
    }

    return {
      'header': headerText,
      'body': bodyText,
      'footer': footerText,
      'image': imageUrl,
      'video': videoUrl,
      'buttons': buttonsList,
      'interactiveMessage': interactiveMessage
    };
  }
String formatMessageText(String messageText) {
  if (messageText.isEmpty) return '';

  if (!isJson(messageText)) {
    return replaceDynamicVariables(messageText, 
    {"name": senderName??'sadcsdv'}
    );
  }

  try {
    final Map<String, dynamic> parsedJson = jsonDecode(messageText);
    // interactive ya template ho toh empty return karo
    // buildInteractiveContent handle karega
    if (parsedJson.containsKey('interactive') ||
        parsedJson.containsKey('template') ||
        parsedJson.containsKey('type')) {
      return '';
    }
    return '';
  } catch (e) {
    return '';
  }
}
//   String formatMessageText(String messageText) {
//     if (messageText.isEmpty) {
//       return '';
//     }

//   if (!isJson(messageText)) {
//     return replaceDynamicVariables(messageText, {
//       "name":"priya" // 🔥 Replace with dynamic user data
//     });
//   }

//     try {
//       final Map<String, dynamic> parsedJson = jsonDecode(messageText); 
//       if(parsedJson.containsKey('type')){
//       return parsedJson['type'].toString();

//       }else{
//         return '';
//       }
// //       final Map<String, dynamic> parsedJson = jsonDecode(messageText);
// //       String to = parsedJson['to']?.toString() ?? '';
// //       String body = parsedJson['text']?['body'] ?? '';
// //       bool previewUrl = parsedJson['text']?['preview_url'] ?? false;
// // // if(messageTextData.containsKey('template'))
// //       return ' $body';
//     } catch (e) {
//       print('Error parsing messageText: $e');
//       return '';
//     }
//   }

  @override
  Widget build(BuildContext context) {
    // if (messageType == "template") {
    final parsedData = parseTemplateData();
    return BaseMessageUi(
      isSentByMe: isSentByMe,
      createdAt: createdAt,
      mediaQuery: mediaQuery,
      deliveryStatus: deliveryStatus,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (parsedData['video'] != null && parsedData['video']!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: VideoMessageUi(
                videoUrl: parsedData['video']!,
                isSentByMe: isSentByMe,
                createdAt: createdAt,
                mediaQuery: mediaQuery,
                rightMargin: 0.0,
                leftMargin: 0.0,
                isInTemplate: true,
                deliveryStatus: deliveryStatus,
              ),
            ),
          if (parsedData['image'] != null && parsedData['image']!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Image.network(parsedData['image']!),
            ),
          if (parsedData['header'] != null && parsedData['header']!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: SelectableText(
                parsedData['header']!,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          if (parsedData['body'] != null && parsedData['body']!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: SelectableText(
                parsedData['body']!,
                style: const TextStyle(color: Colors.black87),
              ),
            ),
          if (messageText.isNotEmpty || templateData == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: SelectableText(
                formatMessageText(messageText),
                style: const TextStyle(color: Colors.black87),
              ),
            ),
          if (parsedData['footer'] != null && parsedData['footer']!.isNotEmpty)
            SelectableText(
              parsedData['footer']!,
              style: const TextStyle(color: Colors.black54),
            ),
          if (parsedData['buttons'] != null &&
              parsedData['buttons']!.isNotEmpty)
            Column(
              children: [
                const Divider(
                  height: 20,
                  thickness: 1,
                  color: Colors.grey,
                ),
                for (var q in parsedData['buttons'])
                  TextButton(
                    onPressed: () {},
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.link),
                        const SizedBox(width: 12),
                        SelectableText(q['text'].toString()),
                      ],
                    ),
                  ),
                const Divider(
                  height: 20,
                  thickness: 1,
                  color: Colors.grey,
                ),
              ],
            ),
          if (parsedData['interactiveMessage'] != null &&
              parsedData['interactiveMessage']!.isNotEmpty)
            buildInteractiveContent(parsedData['interactiveMessage'])
        ],
      ),
    );
  }

  Widget buildInteractiveContent(Map<String, dynamic> interactive) {
    List<Widget> children = [];

    // Handle "header" if present
    if (interactive.containsKey("header")) {
      final header = interactive["header"];

      if (header["type"] == "text") {
        children.add(SelectableText(header["text"] ?? "",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)));
      } else if (header["type"] == "document" &&
          header.containsKey("document")) {
        final document = header["document"];
        children.add(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText("📄 Document Attached:",
                style: TextStyle(fontWeight: FontWeight.bold)),
            SelectableText("📎 ${document["filename"]}"),
            TextButton(
              onPressed: () async {
//          openDocumentLink(document["link"],document["link"]);
// print(document["link"]);
              },
              child: SelectableText("🔗  Document",
                  style: TextStyle(color: Colors.blue)),
            ),
          ],
        ));
      } else if (header["type"] == "image" && header.containsKey("image")) {
        children.add(Image.network(header["image"]["link"]));
      } else if (header["type"] == "video" && header.containsKey("video")) {
        children.add(SelectableText(
            "🎥 Video Attached: ${header["video"]["filename"] ?? ""}"));
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: VideoMessageUi(
            videoUrl: header["video"]["link"]!,
            isSentByMe: isSentByMe,
            createdAt: createdAt,
            mediaQuery: mediaQuery,
            rightMargin: 0.0,
            leftMargin: 0.0,
            isInTemplate: true,
            deliveryStatus: deliveryStatus,
          ),
        ));
//       children.add(TextButton(
//         onPressed: () {
//           openDocumentLink(header["video"]["link"]);
// print(header["video"]["link"]);
//          // launchUrl(Uri.parse(header["video"]["link"]));
//         },
//         child: SelectableText("🔗 Watch Video", style: TextStyle(color: Colors.blue)),
//       ));
      }
    }

    // Handle "body" if present
    if (interactive.containsKey("body")) {
      children.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: SelectableText(
          interactive["body"]["text"] ?? "",
          style: TextStyle(fontSize: 16),
        ),
      ));
    }

    // Handle "footer" if present
    if (interactive.containsKey("footer")) {
      children.add(SelectableText(interactive["footer"]["text"] ?? "",
          style: TextStyle(fontSize: 14, color: Colors.grey)));
    }

    // Handle "button" type interactive messages
    if (interactive.containsKey("action") &&
        interactive["action"].containsKey("buttons")) {
      List<dynamic> buttons = interactive["action"]["buttons"];
      children.addAll(buttons.map((button) {
        return Column(
          children: [
            const Divider(
              height: 10,
              thickness: 1,
              color: Colors.grey,
            ),
            TextButton(
              onPressed: () {},
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.link),
                  const SizedBox(width: 12),
                  SelectableText(button['reply']['title'].toString()),
                ],
              ),
            ),
          ],
        );

        // return ElevatedButton(
        //   onPressed: () {
        //     print("Button clicked: ${button['reply']['id']}");
        //   },
        //   child: SelectableText(button["reply"]["title"]),
        // );
      }).toList());
    }

    // Handle List Reply
    if (interactive.containsKey("list_reply")) {
      final listReply = interactive["list_reply"];
      children.add(Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: ListTile(
          title: Text(listReply["title"] ?? "No Title",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          subtitle: Text(listReply["description"] ?? "No Description",
              style: TextStyle(fontSize: 14, color: Colors.grey)),
          tileColor: Colors.white,
        ),
      ));
    }

    // Handle Flow Messages
    if (interactive.containsKey("flow")) {
      final flowData = interactive['action'] ?? {};
      children.add(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SelectableText("Flow Interactive Message",
          //     style: TextStyle(fontWeight: FontWeight.bold)),
          // SelectableText("Flow ID: ${flowData['parameters']['flow_id']??""}"),
          // SelectableText("CTA: ${flowData['parameters']['flow_cta']??""}"),
          // SelectableText("Action: ${flowData['parameters']['flow_action'??""]}"),
          // SelectableText("Action: ${flowData['parameters']['display_text']??""}"),
          // SelectableText(
          //     "Payload: ${jsonEncode(flowData['parameters']['flow_action_payload'])}"),
        ],
      ));
    }
    if (interactive.containsKey("action") &&
        interactive["action"]["name"] == "cta_url") {
      String url = interactive["action"]["parameters"]["url"] ?? "#";
      String displayText =
          interactive["action"]["parameters"]["display_text"] ?? "Open Link";

      children.add(
        GestureDetector(
          onTap: () async {
            // if (await canLaunchUrl(Uri.parse(url))) {
            //   await launchUrl(Uri.parse(url));
            // } else {
            //   print("Could not launch $url");
            // }
          },
          child: TextButton(
            onPressed: () {},
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.link),
                const SizedBox(width: 12),
                SelectableText(displayText),
              ],
            ),
          ),
        ),
      );
    }
    // Handle NFM Replies
    if (interactive.containsKey("nfm_reply")) {
      final nfmResponse =
          jsonDecode(interactive['nfm_reply']['response_json'] ?? "{}");
      children.add(SelectableText('Form Sent',
          style: TextStyle(fontWeight: FontWeight.bold)));
    }

    // Handle Button Reply Messages
  if (interactive.containsKey("button_reply")) {
  final buttonReply = interactive["button_reply"];
  children.add(
    Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app, size: 16, color: Colors.blue.shade600),
          const SizedBox(width: 8),
          Text(
            buttonReply["title"] ?? "Button Reply",
            style: TextStyle(
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ),
  );
}
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

// Future<void> openDocumentLink(String url) async {
// Future<void> openDocumentLink(String url, String fileName) async {
//   try {
//     // Get the directory to save the file
//     Directory directory = await getApplicationDocumentsDirectory();
//     String filePath = "${directory.path}/$fileName";

//     // Start the download
//     Dio dio = Dio();
//     await dio.download(url, filePath);

//     // Show success message
//     Get.snackbar(
//       "Success",
//       "File downloaded successfully!\nSaved at: $filePath",
//       snackPosition: SnackPosition.BOTTOM,
//       backgroundColor: Colors.green,
//       colorText: Colors.white,
//     );

//     debugPrint("File saved at: $filePath");
//   } catch (e) {
//     // Show error message
//     Get.snackbar(
//       "Error",
//       "Download failed: $e",
//       snackPosition: SnackPosition.BOTTOM,
//       backgroundColor: Colors.red,
//       colorText: Colors.white,
//     );

//     debugPrint("Download error: $e");
//   }
// }
// }
}

    // else if (messageType == "interactive") {
    //   // Handle interactive message logic here
    //   return BaseMessageUi(
    //     isSentByMe: isSentByMe,
    //     createdAt: createdAt,
    //     mediaQuery: mediaQuery,
    //     deliveryStatus: deliveryStatus,
    //     child: Column(
    //       crossAxisAlignment: CrossAxisAlignment.start,
    //       children: [
    //         Text("Interactive Message Type Detected",
    //             style: TextStyle(fontWeight: FontWeight.bold)),
    //         SelectableText(messageText),
    //         // Add other UI elements based on interactive message structure
    //       ],
    //     ),
    //   );
    // }
  
//    ; } else if (messageType == "interactive") {
//       try {
        // final Map<String, dynamic> interactiveData = jsonDecode(messageText);
        // final Map<String, dynamic>? interactive =
        //     interactiveData['interactive'];

//         if (interactive != null) {
//           String type = interactive['type'] ?? 'unknown';

//           Widget content;

//           switch (type) {
//             case "button_reply":
//               content = Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Text("Button Reply",
//                   //     style: TextStyle(fontWeight: FontWeight.bold)),
//                   // Text("Button ID: ${interactive['button_reply']['id']}"),
//                   Text(" ${interactive['button_reply']['title']}"),
//                 ],
//               );
//               break;

//             case "flow":
//               final flowData = interactive['action'] ?? {};
//               content = Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text("Flow Interactive Message",
//                       style: TextStyle(fontWeight: FontWeight.bold)),
//                   Text("Flow ID: ${flowData['parameters']['flow_id']}"),
//                   Text("CTA: ${flowData['parameters']['flow_cta']}"),
//                   Text("Action: ${flowData['parameters']['flow_action']}"),
//                   Text(
//                       "Payload: ${jsonEncode(flowData['parameters']['flow_action_payload'])}"),
//                 ],
//               );
//               break;

//             case "nfm_reply":
//               final nfmResponse =
//                   jsonDecode(interactive['nfm_reply']['response_json'] ?? "{}");
//               content = Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text('Sent', style: TextStyle(fontWeight: FontWeight.bold))

//                   // Text("NFM Reply Received",
//                   //     style: TextStyle(fontWeight: FontWeight.bold)),
//                   // Text("Response: ${jsonEncode(nfmResponse)}"),
//                   // Text("Body: ${interactive['nfm_reply']['body']}"),
//                 ],
//               );
//               break;
//             case "list_reply":
//               final listReply = interactive['list_reply'] ?? {};
//               // var listReply = messageData["interactive"]["list_reply"][""];
//               String title = listReply["title"] ?? "No Title";
//               String description = listReply["description"] ?? "No Description";
//               print(listReply.toString());
//               content = Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
// // Text("nfmResponse")
//                   ListTile(
//                     title: Text(title,
//                         style: TextStyle(
//                             fontSize: 18, fontWeight: FontWeight.bold)),
//                     subtitle: Text(description,
//                         style: TextStyle(fontSize: 14, color: Colors.grey)),
//                     tileColor: Colors.white,
//                     shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(8)),
//                     contentPadding: EdgeInsets.all(10),
//                   )
//                 ],
//               );
//               break;

//             default:
//               content = Text("Unknown Interactive Message Type: $type");
//           }

//           return BaseMessageUi(
//             isSentByMe: isSentByMe,
//             createdAt: createdAt,
//             mediaQuery: mediaQuery,
//             deliveryStatus: deliveryStatus,
//             child: content,
//           );
//         }
//       } catch (e) {
//         print("Error parsing interactive message: $e");
//       }

//       return BaseMessageUi(
//         isSentByMe: isSentByMe,
//         createdAt: createdAt,
//         mediaQuery: mediaQuery,
//         deliveryStatus: deliveryStatus,
//         child: SelectableText("Invalid interactive message format"),
//       );
//     }

    // else {
    //   // Default case
    //   return BaseMessageUi(
    //     isSentByMe: isSentByMe,
    //     createdAt: createdAt,
    //     mediaQuery: mediaQuery,
    //     deliveryStatus: deliveryStatus,
    //     child: SelectableText("Unknown message type"),
    //   );
    // }


