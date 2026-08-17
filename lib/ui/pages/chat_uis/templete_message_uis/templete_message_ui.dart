import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:getgabs/ui/pages/chat_uis/vide_message_uis/video_message_ui.dart';
import '../base_message_ui.dart';

class TempleteMessageUi extends StatefulWidget {
  final String? templateData;
  final String messageText;
  final bool isSentByMe;
  final DateTime createdAt;
  final Size mediaQuery;
  final String deliveryStatus;
  final String messageType;
   final String? senderName;
  final bool isAutoreply;

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
    this.isAutoreply = false,
  });

  @override
  State<TempleteMessageUi> createState() => _TempleteMessageUiState();
}

class _TempleteMessageUiState extends State<TempleteMessageUi> {
  // Received templates start collapsed (short preview, tap to reveal the
  // full message) — sent-by-me templates are never collapsed. Once
  // expanded it stays expanded; there's no need to re-collapse.
  bool _expanded = false;
  bool _flashHighlight = false;

  void _expand() {
    setState(() {
      _expanded = true;
      _flashHighlight = true;
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _flashHighlight = false);
    });
  }

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

  static final RegExp _markdownMarker = RegExp(r'\*(.+?)\*|_(.+?)_');

  // WhatsApp-style markdown — *bold* and _italic_ — arrives as literal
  // asterisks/underscores in plain-text bot messages (they're not real
  // WhatsApp interactive JSON), so it needs parsing here instead of just
  // being shown raw.
  List<InlineSpan> _parseWhatsAppMarkdown(String text, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    var lastEnd = 0;
    for (final match in _markdownMarker.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
            text: text.substring(lastEnd, match.start), style: baseStyle));
      }
      if (match.group(1) != null) {
        spans.add(TextSpan(
            text: match.group(1),
            style: baseStyle.copyWith(fontWeight: FontWeight.bold)));
      } else if (match.group(2) != null) {
        spans.add(TextSpan(
            text: match.group(2),
            style: baseStyle.copyWith(fontStyle: FontStyle.italic)));
      }
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
    }
    return spans;
  }

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

    try {
      if (widget.templateData != null && widget.templateData!.isNotEmpty) {
        final decodedTemplate = decodeJsonPayload(widget.templateData!);
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

      if (widget.messageText.isNotEmpty) {
        final dynamic rawMessageData = decodeJsonPayload(widget.messageText);
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
      debugPrint('Error parsing template data: $e');
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
        {"name": widget.senderName ?? ''},
      );
    }

    if (decoded is String) {
      return replaceDynamicVariables(
        decoded,
        {"name": widget.senderName ?? ''},
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

  @override
  Widget build(BuildContext context) {
    final parsedData = parseTemplateData();
    final inline = extractInlineButtons(formatMessageText(widget.messageText));
    final formattedText = inline['text'] as String;
    final inlineButtons = inline['buttons'] as List<Map<String, String>>;

    final headerText = parsedData['header'] as String;
    final bodyText = parsedData['body'] as String;
    final footerText = parsedData['footer'] as String;
    final imageUrl = parsedData['image'] as String;
    final videoUrl = parsedData['video'] as String;
    final buttonsList = parsedData['buttons'] as List<Map<String, String>>;
    final interactiveMessage =
        parsedData['interactiveMessage'] as Map<String, dynamic>;

    // A received template only collapses when there's actually meaningful
    // extra content to hide behind a tap (media/buttons/footer/interactive,
    // or a long enough body) — a short one-line template has nothing worth
    // condensing. Sent-by-me templates are never collapsed.
    final previewLength = headerText.length + bodyText.length + formattedText.length;
    final hasExtras = footerText.isNotEmpty ||
        buttonsList.isNotEmpty ||
        interactiveMessage.isNotEmpty ||
        inlineButtons.isNotEmpty ||
        imageUrl.isNotEmpty ||
        videoUrl.isNotEmpty ||
        previewLength > 140;
    final canCollapse = !widget.isSentByMe && hasExtras;
    final collapsed = canCollapse && !_expanded;

    Widget content;
    if (collapsed) {
      final previewSpans = <InlineSpan>[];
      if (headerText.isNotEmpty) {
        previewSpans.addAll(_parseWhatsAppMarkdown(
          headerText,
          const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ));
        previewSpans.add(const TextSpan(text: '  '));
      }
      final restText =
          [bodyText, formattedText].where((t) => t.isNotEmpty).join('\n');
      if (restText.isNotEmpty) {
        previewSpans.addAll(_parseWhatsAppMarkdown(
          restText,
          const TextStyle(color: Colors.black87),
        ));
      }

      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isAutoreply)
            const Padding(
              padding: EdgeInsets.only(bottom: 6.0),
              child: Text(
                'AI Agent',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                  color: Color(0xFFD32F2F),
                ),
              ),
            ),
          if (previewSpans.isNotEmpty)
            Text.rich(
              TextSpan(children: previewSpans),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.unfold_more, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                'Tap to view full message',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      );
      content = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _expand,
        child: content,
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isAutoreply)
            const Padding(
              padding: EdgeInsets.only(bottom: 6.0),
              child: Text(
                'AI Agent',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                  color: Color(0xFFD32F2F),
                ),
              ),
            ),
          if (videoUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: VideoMessageUi(
                videoUrl: videoUrl,
                isSentByMe: widget.isSentByMe,
                createdAt: widget.createdAt,
                mediaQuery: widget.mediaQuery,
                rightMargin: 0.0,
                leftMargin: 0.0,
                isInTemplate: true,
                deliveryStatus: widget.deliveryStatus,
              ),
            ),
          if (imageUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Image.network(
                imageUrl,
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
          if (headerText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: SelectableText.rich(
                TextSpan(
                  children: _parseWhatsAppMarkdown(
                    headerText,
                    const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          if (bodyText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: SelectableText.rich(
                TextSpan(
                  children: _parseWhatsAppMarkdown(
                    bodyText,
                    const TextStyle(color: Colors.black87),
                  ),
                ),
              ),
            ),
          if (formattedText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: SelectableText.rich(
                TextSpan(
                  children: _parseWhatsAppMarkdown(
                    formattedText,
                    const TextStyle(color: Colors.black87),
                  ),
                ),
              ),
            ),
          if (footerText.isNotEmpty)
            SelectableText(
              footerText,
              style: const TextStyle(color: Colors.black54),
            ),
          if (buttonsList.isNotEmpty)
            Column(
              children: [
                const Divider(
                  height: 20,
                  thickness: 1,
                  color: Colors.grey,
                ),
                for (var q in buttonsList)
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
          if (interactiveMessage.isNotEmpty)
            buildInteractiveContent(interactiveMessage),
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
      );
    }

    return BaseMessageUi(
      isSentByMe: widget.isSentByMe,
      createdAt: widget.createdAt,
      mediaQuery: widget.mediaQuery,
      deliveryStatus: widget.deliveryStatus,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: _flashHighlight
            ? const Color(0xFFD3E3FD)
            : Colors.transparent,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          alignment: Alignment.topLeft,
          child: content,
        ),
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
              onPressed: () async {},
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
            isSentByMe: widget.isSentByMe,
            createdAt: widget.createdAt,
            mediaQuery: widget.mediaQuery,
            rightMargin: 0.0,
            leftMargin: 0.0,
            isInTemplate: true,
            deliveryStatus: widget.deliveryStatus,
          ),
        ));
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
      children.add(const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [],
      ));
    }
    if (interactive.containsKey("action") &&
      interactive["action"]["name"] == "cta_url") {
      String displayText =
        interactive["action"]["parameters"]["display_text"] ?? "Open Link";

      children.add(
        GestureDetector(
          onTap: () async {},
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
}
