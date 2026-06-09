import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'contact_message_ui_controller.dart';
import '../base_message_ui.dart';

class ContactMessageUi extends StatefulWidget {
  final String documentFile;
  final bool isSentByMe;
  final DateTime createdAt;
  final Size mediaQuery;
  final double rightMargin;
  final double leftMargin;
  final bool isInTemplate;
  final bool isLocal;
  final String deliveryStatus;

  const ContactMessageUi({
    super.key,
    required this.documentFile,
    required this.isSentByMe,
    required this.createdAt,
    required this.mediaQuery,
    this.rightMargin = 0,
    this.leftMargin = 0,
    this.isInTemplate = false,
    this.isLocal = false,
    required this.deliveryStatus,
  });

  @override
  State<ContactMessageUi> createState() => _ContactMessageUiState();
}

class _ContactMessageUiState extends State<ContactMessageUi> {
  late ContactMessageUiController controller;
  late String tag;

  @override
  void initState() {
    super.initState();
    tag = 'contact_${widget.documentFile.hashCode}';
    
    // Delete old controller if exists
    if (Get.isRegistered<ContactMessageUiController>(tag: tag)) {
      Get.delete<ContactMessageUiController>(tag: tag);
    }
    
    // Create new controller
    controller = Get.put(ContactMessageUiController(), tag: tag);
    
    // Parse data after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.parseContactData(widget.documentFile);
    });
  }

  @override
  void dispose() {
    if (Get.isRegistered<ContactMessageUiController>(tag: tag)) {
      Get.delete<ContactMessageUiController>(tag: tag);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseMessageUi(
      isSentByMe: widget.isSentByMe,
      createdAt: widget.createdAt,
      mediaQuery: widget.mediaQuery,
      deliveryStatus: widget.deliveryStatus,
      child: GestureDetector(
        // onTap: () => controller.showContactOptions(),
        child: 
        Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Contact Info
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Avatar
                    Obx(() => CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.teal,
                      child: Text(
                        controller.getInitials(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    )),
                    const SizedBox(width: 12),
                    // Name & Phone
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name
                          Obx(() => Text(
                            controller.contactName.value,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )),
                          const SizedBox(height: 4),
                          // Phone
                          Obx(() {
                            if (controller.hasPhone) {
                              return Row(
                                children: [
                                  Icon(Icons.phone, size: 14, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      controller.contactPhone.value,
                                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              );
                            }
                            return Text(
                              'No phone number',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                                fontStyle: FontStyle.italic,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Divider
              Divider(height: 1, color: Colors.grey.shade300),
              // Action Buttons
              Row(
                children: [
                  // Message Button
                  Expanded(
                    child: Obx(() => InkWell(
                      // onTap: controller.hasPhone ? () => controller.getgabs() : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.message,
                              size: 18,
                              color: controller.hasPhone ? Colors.teal : Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Message',
                              style: TextStyle(
                                color: controller.hasPhone ? Colors.teal : Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
                  ),
                  // Divider
                  Container(width: 1, height: 40, color: Colors.grey.shade300),
                  // Copy Button
                  Expanded(
                    child: Obx(() => InkWell(
                      onTap: controller.hasPhone ? () => controller.copyToClipboard() : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.copy,
                              size: 18,
                              color: controller.hasPhone ? Colors.teal : Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Copy',
                              style: TextStyle(
                                color: controller.hasPhone ? Colors.teal : Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  }
}