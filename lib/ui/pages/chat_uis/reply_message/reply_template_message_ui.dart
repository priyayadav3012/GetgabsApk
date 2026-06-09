import 'package:flutter/material.dart';
import 'package:getgabs/ui/pages/chat_uis/reply_message/reply_base_message_ui.dart';
import 'package:getgabs/ui/pages/chat_uis/reply_message/reply_video_message_ui.dart';
import 'dart:convert';

class ReplyTempleteMessageUi extends StatelessWidget {
  final String ? templateData;
  final String messageText;
  final Size mediaQuery;
  

  const ReplyTempleteMessageUi({super.key, 
    required this.templateData,
    required this.messageText,
    required this.mediaQuery,
   
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

  Map<String, dynamic> parseTemplateData() {
    String headerText = '';
    String bodyText = '';
    String footerText = '';
    String imageUrl = '';
    String videoUrl = '';
    List<Map<String, String>> buttonsList = [];
    String templateName = '';

    try {
      if (templateData != null && templateData!.isNotEmpty) {
        final Map<String, dynamic> templateDataMap = jsonDecode(templateData!);

        if (templateDataMap.containsKey('data') &&
            templateDataMap['data'].isNotEmpty &&
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
                imageUrl = component['example']?['header_handle']?[0] ?? '';
              } else if (component.containsKey('format') &&
                  component['format'] == 'VIDEO') {
                videoUrl = component['example']?['header_handle']?[0] ?? '';
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

                buttonsList.add(
                    {'text': buttonText, 'type': buttonType, 'url': buttonUrl});
              }
            }
          }
        }
      }
      
      if (messageText.isNotEmpty) {
        final Map<String, dynamic> messageTextData = jsonDecode(messageText);

        // Get template name if available
        if (messageTextData.containsKey('template') &&
            messageTextData['template'].containsKey('name')) {
          templateName = messageTextData['template']['name'] ?? '';
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
                      imageUrl = parameters[0]['image']?['link'] ?? '';
                    } else if (parameterType == 'VIDEO') {
                      videoUrl = parameters[0]['video']?['link'] ?? '';
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
        }
      }
    } catch (e) {
      print('Error parsing template data: $e');
      print('Template data: $templateData');
      print('Message text: $messageText');
    }

    return {
      'header': headerText,
      'body': bodyText,
      'footer': footerText,
      'image': imageUrl,
      'video': videoUrl,
      'buttons': buttonsList,
      'templateName': templateName,
    };
  }
String formatMessageText(String messageText) {
  if (messageText.isEmpty) {
    return 'No message available';
  }

  try {
    final Map<String, dynamic> parsedJson = jsonDecode(messageText);

    String to = parsedJson['to']?.toString() ?? '';
    String body = parsedJson['text']?['body'] ?? 'Templete';
    bool previewUrl = parsedJson['text']?['preview_url'] ?? false;

    return ' $body';
  } catch (e) {
    
    print('Error parsing messageText: $e');
    return 'Invalid message format';
  }
}
  @override
  Widget build(BuildContext context) {
    final parsedData = parseTemplateData();
    
    // If we have a template name but no content, show template name
    final hasContent = parsedData['header']!.isNotEmpty ||
        parsedData['body']!.isNotEmpty ||
        parsedData['image']!.isNotEmpty ||
        parsedData['video']!.isNotEmpty;
    
    if (!hasContent && parsedData['templateName']!.isNotEmpty) {
      return ReplyBaseMessageUi(
        mediaQuery: mediaQuery,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.article_outlined,
              size: 16,
              color: Colors.grey,
            ),
            const SizedBox(height: 4),
            Text(
              'Template: ${parsedData['templateName']}',
              style: const TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      );
    }
    
    return ReplyBaseMessageUi(
    
      
      mediaQuery: mediaQuery,
     
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (parsedData['video'] != null && parsedData['video']!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: ReplyVideoMessageUi(
                videoUrl: parsedData['video']!,
               
                
                mediaQuery: mediaQuery,
                
                isInTemplate: true,
                
              ),
            ),

          // Padding(
          //   padding: const EdgeInsets.only(bottom: 8.0),
          //   child: VideoMessageUi(
          //     videoUrl: parsedData['video']!,
          //     isSentByMe: isSentByMe,
          //     createdAt: createdAt,
          //     mediaQuery: mediaQuery,
          //     rightMargin: 0.0, // Adjust as needed
          //     leftMargin: 0.0, // Adjust as needed
          //   ),
          // ),
            if (parsedData['image'] != null && parsedData['image']!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Image.network(parsedData['image']!),
          ),
        if (parsedData['header'] != null && parsedData['header']!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
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
            child: Text(
              parsedData['body']!,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        if (messageText.isNotEmpty || templateData == null)
  Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Text(
      formatMessageText(messageText), // Use formatted message
      style: const TextStyle(color: Colors.black87),
    ),
  ),
        if (parsedData['footer'] != null && parsedData['footer']!.isNotEmpty)
          Text(
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
                      Text(q['text'].toString()),
                    ],
                  ),
                ),
              const Divider(
                height: 20,
                thickness: 1,
                color: Colors.grey,
              ),

              ]
            )
        ],
      ),
    );
  }
}

