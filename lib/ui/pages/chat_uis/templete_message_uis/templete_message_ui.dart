import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:getgabs/ui/pages/chat_uis/vide_message_uis/video_message_ui.dart';
import '../base_message_ui.dart';

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
  String replaceDynamicVariables(String text, Map<String, String> values) {
    values.forEach((key, value) {
      text = text.replaceAll('{$key}', value);
    });
    return text;
  }

  dynamic decodeJsonPayload(String input) {
    if (input.isEmpty) return null;

    try {
      final decoded = jsonDecode(input);
      if (decoded is String) {
        return decodeJsonPayload(decoded);
      }
      return decoded;
    } catch (_) {
      // Handle escaped JSON string values and partial JSON content.
    }

    final trimmed = input.trim();
    if (trimmed.startsWith('"') && trimmed.endsWith('"')) {
      try {
        final inner = jsonDecode(trimmed);
        if (inner is String) {
          return decodeJsonPayload(inner);
        }
      } catch (_) {}
    }

    final jsonStart = trimmed.indexOf('{');
    final jsonEnd = trimmed.lastIndexOf('}');
    if (jsonStart != -1 && jsonEnd != -1 && jsonEnd > jsonStart) {
      final candidate = trimmed.substring(jsonStart, jsonEnd + 1);
      try {
        final decoded = jsonDecode(candidate);
        if (decoded is String) {
          return decodeJsonPayload(decoded);
        }
        return decoded;
      } catch (_) {}
    }

    return null;
  }

  bool isJson(String str) => decodeJsonPayload(str) != null;

  static final RegExp _inlineButtonMarker =
      RegExp(r'\((List )?Button:\s*([^)]+)\)');
  static final RegExp _labelUrlSplit =
      RegExp(r'^(.*?)\s*-\s*(https?://\S+)$');

  // Some outgoing bot messages carry plain-text placeholder markers like
  // "(Button: Visit Website - https://example.com)" or
  // "(List Button: Select Option)" instead of real WhatsApp interactive
  // JSON. Strip those markers out of the displayed text and turn them
  // into actual button rows below the message.
  Map<String, dynamic> extractInlineButtons(String text) {
    final buttons = <Map<String, String>>[];
    for (final match in _inlineButtonMarker.allMatches(text)) {
      final isList = match.group(1) != null;
      final content = match.group(2)!.trim();
      final split = _labelUrlSplit.firstMatch(content);
      buttons.add({
        'label': split != null ? split.group(1)!.trim() : content,
        'url': split != null ? split.group(2)!.trim() : '',
        'isList': isList.toString(),
      });
    }
    final cleanedText = text.replaceAll(_inlineButtonMarker, '').trim();
    return {'text': cleanedText, 'buttons': buttons};
  }

  String getInteractivePreview(Map<String, dynamic> interactive) {
    if (interactive['body'] is Map &&
        interactive['body']['text'] != null &&
        interactive['body']['text'].toString().isNotEmpty) {
      return interactive['body']['text'].toString();
    }

    if (interactive['header'] is Map &&
        interactive['header']['text'] != null &&
        interactive['header']['text'].toString().isNotEmpty) {
      return interactive['header']['text'].toString();
    }

    if (interactive['button_reply'] is Map &&
        interactive['button_reply']['title'] != null) {
      return interactive['button_reply']['title'].toString();
    }

    if (interactive['list_reply'] is Map &&
        interactive['list_reply']['title'] != null) {
      return interactive['list_reply']['title'].toString();
    }

    return '';
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
      if (templateData != null && templateData!.isNotEmpty) {
        final decodedTemplate = decodeJsonPayload(templateData!);
        if (decodedTemplate is Map<String, dynamic> &&
            decodedTemplate.containsKey('data')) {
          final data = decodedTemplate['data'];
          if (data is List && data.isNotEmpty &&
              data[0] is Map<String, dynamic> &&
              data[0].containsKey('components')) {
            final List<dynamic> components = data[0]['components'];
            for (var component in components) {
              if (component is Map<String, dynamic>) {
                final type = (component['type'] as String?)?.toUpperCase() ?? '';
                if (type == 'HEADER') {
                  if (component.containsKey('text')) {
                    headerText = component['text']?.toString() ?? '';
                  }
                  if (component['format'] == 'IMAGE') {
                    imageUrl = component['example']?['header_handle']?[0] ?? '';
                  } else if (component['format'] == 'VIDEO') {
                    videoUrl = component['example']?['header_handle']?[0] ?? '';
                  }
                } else if (type == 'BODY') {
                  bodyText = component['text']?.toString() ?? '';
                } else if (type == 'FOOTER') {
                  footerText = component['text']?.toString() ?? '';
                } else if (type == 'BUTTONS' && component.containsKey('buttons')) {
                  final buttons = component['buttons'];
                  if (buttons is List) {
                    for (var button in buttons) {
                      if (button is Map<String, dynamic>) {
                        final buttonText = button['text']?.toString() ?? '';
                        final buttonType = button['type']?.toString() ?? '';
                        final buttonUrl = buttonType == 'URL'
                            ? button['url']?.toString() ?? ''
                            : '';
                        buttonsList.add({
                          'text': buttonText,
                          'type': buttonType,
                          'url': buttonUrl,
                        });
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      if (messageText.isNotEmpty) {
        final dynamic rawMessageData = decodeJsonPayload(messageText);
        if (rawMessageData is Map<String, dynamic>) {
          if (rawMessageData.containsKey('template') &&
              rawMessageData['template'] is Map<String, dynamic> &&
              rawMessageData['template']['components'] is List) {
            final List<dynamic> templateComponents =
                rawMessageData['template']['components'];
            for (var component in templateComponents) {
              if (component is Map<String, dynamic> &&
                  component.containsKey('parameters')) {
                final parameters = component['parameters'] as List<dynamic>;
                final type = (component['type'] as String?)?.toUpperCase() ?? '';
                if (type == 'HEADER') {
                  headerText = replaceTemplateVariables(headerText, parameters);
                  if (parameters.isNotEmpty) {
                    final parameterType = parameters[0]['type'];
                    if (parameterType == 'IMAGE') {
                      imageUrl = parameters[0]['image']?['link']?.toString() ?? '';
                    } else if (parameterType == 'VIDEO') {
                      videoUrl = parameters[0]['video']?['link']?.toString() ?? '';
                    }
                  }
                } else if (type == 'BODY') {
                  bodyText = replaceTemplateVariables(bodyText, parameters);
                } else if (type == 'FOOTER') {
                  footerText = replaceTemplateVariables(footerText, parameters);
                }
              }
            }
          }

          if (rawMessageData.containsKey('interactive')) {
            final dynamic interactiveRaw = rawMessageData['interactive'];
            if (interactiveRaw is Map<String, dynamic>) {
              interactiveMessage = interactiveRaw;
            } else if (interactiveRaw is String) {
              final decodedInteractive = decodeJsonPayload(interactiveRaw);
              if (decodedInteractive is Map<String, dynamic>) {
                interactiveMessage = decodedInteractive;
              }
            }
          }
          if (rawMessageData['type'] == 'interactive' &&
              rawMessageData.containsKey('interactive')) {
            final dynamic interactiveRaw = rawMessageData['interactive'];
            if (interactiveRaw is Map<String, dynamic>) {
              interactiveMessage = interactiveRaw;
            }
          }
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

  final decoded = decodeJsonPayload(messageText);
  if (decoded == null) {
    return replaceDynamicVariables(
      messageText,
      {"name": senderName ?? ''},
    );
  }

  if (decoded is String) {
    return replaceDynamicVariables(
      decoded,
      {"name": senderName ?? ''},
    );
  }

  if (decoded is Map<String, dynamic>) {
    if (decoded.containsKey('text') && decoded['text'] is Map) {
      return decoded['text']['body']?.toString() ?? '';
    }

    if (decoded.containsKey('interactive')) {
      final dynamic interactive = decoded['interactive'];
      if (interactive is Map<String, dynamic>) {
        return getInteractivePreview(interactive);
      }
      return '';
    }

    if (decoded.containsKey('template')) {
      final dynamic template = decoded['template'];
      if (template is Map && template.containsKey('components')) {
        return '';
      }
    }
  }

  return '';
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
    final inline = extractInlineButtons(formatMessageText(messageText));
    final formattedText = inline['text'] as String;
    final inlineButtons = inline['buttons'] as List<Map<String, String>>;
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
              child: Image.network(
                parsedData['image']!,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 150,
                  width: double.infinity,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image_outlined,
                      color: Colors.grey, size: 32),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 150,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  );
                },
              ),
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
          if (formattedText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: SelectableText(
                formattedText,
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
            buildInteractiveContent(parsedData['interactiveMessage']),
          if (inlineButtons.isNotEmpty)
            Column(
              children: [
                const Divider(height: 20, thickness: 1, color: Colors.grey),
                for (var btn in inlineButtons)
                  TextButton(
                    onPressed: btn['url']!.isNotEmpty
                        ? () => launchUrl(Uri.parse(btn['url']!),
                            mode: LaunchMode.externalApplication)
                        : null,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(btn['isList'] == 'true'
                            ? Icons.list
                            : Icons.link),
                        const SizedBox(width: 12),
                        SelectableText(btn['label']!),
                      ],
                    ),
                  ),
              ],
            ),
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
        children.add(Image.network(
          header["image"]["link"],
          errorBuilder: (context, error, stackTrace) => Container(
            height: 150,
            width: double.infinity,
            color: Colors.grey.shade200,
            child: const Icon(Icons.broken_image_outlined,
                color: Colors.grey, size: 32),
          ),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 150,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(strokeWidth: 2),
            );
          },
        ));
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

    // Handle "button" type interactive messages (render like template buttons)
    if (interactive.containsKey("action") &&
        interactive["action"].containsKey("buttons")) {
      final List<dynamic> buttons = interactive["action"]["buttons"];
      children.add(const Divider(
        height: 20,
        thickness: 1,
        color: Colors.grey,
      ));
      for (var button in buttons) {
        final title = (button is Map && button.containsKey('text'))
            ? (button['text']?.toString() ?? '')
            : (button is Map &&
                    button.containsKey('reply') &&
                    button['reply'] is Map &&
                    button['reply'].containsKey('title'))
                ? (button['reply']['title']?.toString() ?? '')
                : '';

        children.add(TextButton(
          onPressed: () {},
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.link),
              const SizedBox(width: 12),
              SelectableText(title),
            ],
          ),
        ));
      }
      children.add(const Divider(
        height: 20,
        thickness: 1,
        color: Colors.grey,
      ));
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
      // response_json available, but we don't need to use it here
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


