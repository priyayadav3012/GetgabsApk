import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Add this package for number formatting

import '../base_message_ui.dart';

class OrderMessageUi extends StatelessWidget {
  final String text;
  final bool isSentByMe;
  final DateTime createdAt;
  final Size mediaQuery;
  final String deliveryStatus;

  const OrderMessageUi({
    super.key,
    required this.text,
    required this.isSentByMe,
    required this.createdAt,
    required this.mediaQuery,
    required this.deliveryStatus,
  });

  @override
  Widget build(BuildContext context) {
    Widget content;
    double totalAmount = 0;
    String currencySymbol = '₹'; // Default currency symbol

    try {
      if (text.isNotEmpty) {
        final Map<String, dynamic> messageData = jsonDecode(text);
        final List<dynamic>? productItems = messageData['order']?['product_items'];

        if (productItems != null && productItems.isNotEmpty) {
          // Calculate total amount and determine currency
          for (var item in productItems) {
            totalAmount += (item['item_price'] ?? 0) * (item['quantity'] ?? 0);
            currencySymbol = item['currency'] ?? '₹';
          }

          // Using NumberFormat for currency formatting
          final currencyFormatter = NumberFormat.currency(
            locale: 'en_IN', // Indian English for formatting
            symbol: currencySymbol,
            decimalDigits: 2,
          );

          content = Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              // Use a slightly different color based on who sent the message
              color: isSentByMe
                  ? Colors.blue.shade50
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Header ---
                const Row(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.black54, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Order Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),

                // --- Product List ---
                ...productItems.map((item) {
                  final retailerId = item['product_retailer_id'] ?? 'N/A';
                  final quantity = item['quantity'] ?? 0;
                  final price = item['item_price'] ?? 0.0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Icon
                        Icon(Icons.shopping_bag_outlined, color: Colors.grey.shade600, size: 36),
                        const SizedBox(width: 12),
                        // Product Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Product ID: $retailerId',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Qty: $quantity  x  ${currencyFormatter.format(price)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Item Total
                        Text(
                          currencyFormatter.format(quantity * price),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),

                // --- Footer with Total ---
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      currencyFormatter.format(totalAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF2E7D32), // A nice green color
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        } else {
          content = const Text('No order details available.');
        }
      } else {
        // Return an empty container if the text is empty
        content = const SizedBox.shrink();
      }
    } catch (e) {
      // Gracefully handle JSON parsing errors
      content = const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text(
          'Unable to display order.',
          style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic),
        ),
      );
    }

    return BaseMessageUi(
      isSentByMe: isSentByMe,
      createdAt: createdAt,
      mediaQuery: mediaQuery,
      deliveryStatus: deliveryStatus,
      // Pass the content to the base UI.
      // The BaseMessageUi will handle the chat bubble styling.
      child: content,
    );
  }
}
