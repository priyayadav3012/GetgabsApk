import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactMessageUiController extends GetxController {
  late RxString contactName;
  late RxString contactPhone;
  late RxList<String> contactPhones;
  late RxBool isLoading;

  @override
  void onInit() {
    super.onInit();
    contactName = 'Unknown'.obs;
    contactPhone = ''.obs;
    contactPhones = <String>[].obs;
    isLoading = false.obs;
  }

  bool get hasPhone => contactPhone.value.isNotEmpty;

  String getInitials() {
    String n = contactName.value;
    if (n.isEmpty || n == 'Unknown') return 'U';
    
    final cleanName = n.replaceAll(RegExp(r'[^a-zA-Z\s]'), '').trim();
    if (cleanName.isEmpty) return n[0].toUpperCase();
    
    final parts = cleanName.split(' ');
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'U';
  }

  void parseContactData(String rawData) {
    isLoading.value = true;
    
    debugPrint('========================================');
    debugPrint('=== START PARSING ===');
    debugPrint('Raw data: $rawData');
    debugPrint('========================================');
    
    try {
      // Parse JSON
      dynamic decoded;
      try {
        decoded = jsonDecode(rawData);
        debugPrint('JSON decoded successfully');
        debugPrint('Type: ${decoded.runtimeType}');
      } catch (e) {
        debugPrint('JSON decode failed: $e');
        _parseWithRegex(rawData);
        return;
      }

      if (decoded == null) {
        debugPrint('Decoded is null');
        _parseWithRegex(rawData);
        return;
      }

      // Handle Map
      if (decoded is Map) {
        Map<String, dynamic> jsonMap = Map<String, dynamic>.from(decoded);
        debugPrint('Keys in JSON: ${jsonMap.keys.toList()}');
        
        // Check for "contacts" array (WhatsApp message format)
        if (jsonMap.containsKey('contacts')) {
          debugPrint('Found "contacts" key');
          var contactsData = jsonMap['contacts'];
          
          if (contactsData is List && contactsData.isNotEmpty) {
            debugPrint('contacts is List with ${contactsData.length} items');
            var firstContact = contactsData[0];
            debugPrint('First contact: $firstContact');
            
            if (firstContact is Map) {
              _extractFromContact(Map<String, dynamic>.from(firstContact));
            }
          }
        } else {
          // Direct contact object
          debugPrint('No "contacts" key, parsing as direct contact');
          _extractFromContact(jsonMap);
        }
      }
      // Handle List
      else if (decoded is List && decoded.isNotEmpty) {
        debugPrint('Decoded is List with ${decoded.length} items');
        var firstItem = decoded[0];
        if (firstItem is Map) {
          _extractFromContact(Map<String, dynamic>.from(firstItem));
        }
      }

    } catch (e, stack) {
      debugPrint('Error: $e');
      debugPrint('Stack: $stack');
      _parseWithRegex(rawData);
    } finally {
      isLoading.value = false;
      debugPrint('========================================');
      debugPrint('=== FINAL VALUES ===');
      debugPrint('Name: ${contactName.value}');
      debugPrint('Phone: ${contactPhone.value}');
      debugPrint('========================================');
    }
  }

  void _extractFromContact(Map<String, dynamic> contact) {
    debugPrint('--- Extracting from contact ---');
    debugPrint('Contact data: $contact');
    debugPrint('Contact keys: ${contact.keys.toList()}');

    String? name;
    String? phone;
    List<String> phones = [];

    // ========== EXTRACT NAME ==========
    if (contact.containsKey('name')) {
      var nameData = contact['name'];
      debugPrint('nameData: $nameData (${nameData.runtimeType})');
      
      if (nameData is Map) {
        // Try formatted_name first, then first_name
        if (nameData.containsKey('formatted_name')) {
          name = nameData['formatted_name']?.toString();
          debugPrint('Got formatted_name: $name');
        }
        if ((name == null || name.isEmpty) && nameData.containsKey('first_name')) {
          name = nameData['first_name']?.toString();
          debugPrint('Got first_name: $name');
        }
      } else if (nameData is String) {
        name = nameData;
        debugPrint('nameData is String: $name');
      }
    }

    // ========== EXTRACT PHONES ==========
    if (contact.containsKey('phones')) {
      var phonesData = contact['phones'];
      debugPrint('phonesData: $phonesData (${phonesData.runtimeType})');
      
      if (phonesData is List) {
        for (var item in phonesData) {
          debugPrint('Phone item: $item (${item.runtimeType})');
          
          if (item is Map) {
            // Get phone
            if (item.containsKey('phone')) {
              String? p = item['phone']?.toString();
              debugPrint('Found phone: $p');
              if (p != null && p.isNotEmpty) {
                phones.add(p);
              }
            }
            // Get wa_id
            if (item.containsKey('wa_id')) {
              String? w = item['wa_id']?.toString();
              debugPrint('Found wa_id: $w');
              if (w != null && w.isNotEmpty && !phones.contains(w)) {
                phones.add(w);
              }
            }
          } else if (item is String && item.isNotEmpty) {
            phones.add(item);
          }
        }
      }
    }

    // Get first phone
    if (phones.isNotEmpty) {
      phone = phones[0];
    }

    // ========== UPDATE VALUES ==========
    debugPrint('--- Setting values ---');
    debugPrint('name to set: $name');
    debugPrint('phone to set: $phone');
    debugPrint('phones list: $phones');

    if (name != null && name.isNotEmpty) {
      contactName.value = name;
      debugPrint('contactName set to: ${contactName.value}');
    }
    if (phone != null && phone.isNotEmpty) {
      contactPhone.value = phone;
      debugPrint('contactPhone set to: ${contactPhone.value}');
    }
    if (phones.isNotEmpty) {
      contactPhones.value = phones;
    }
  }

  void _parseWithRegex(String data) {
    debugPrint('=== REGEX FALLBACK ===');
    
    // Extract formatted_name
    var nameMatch = RegExp(r'"formatted_name"\s*:\s*"([^"]+)"').firstMatch(data);
    if (nameMatch != null) {
      String? n = nameMatch.group(1);
      debugPrint('Regex formatted_name: $n');
      if (n != null && n.isNotEmpty) {
        contactName.value = n;
      }
    } else {
      // Try first_name
      nameMatch = RegExp(r'"first_name"\s*:\s*"([^"]+)"').firstMatch(data);
      if (nameMatch != null) {
        String? n = nameMatch.group(1);
        debugPrint('Regex first_name: $n');
        if (n != null && n.isNotEmpty) {
          contactName.value = n;
        }
      }
    }

    // Extract phone
    var phoneMatch = RegExp(r'"phone"\s*:\s*"([^"]+)"').firstMatch(data);
    if (phoneMatch != null) {
      String? p = phoneMatch.group(1);
      debugPrint('Regex phone: $p');
      if (p != null && p.isNotEmpty) {
        contactPhone.value = p;
        contactPhones.add(p);
      }
    }

    // Extract wa_id
    var waMatch = RegExp(r'"wa_id"\s*:\s*"([^"]+)"').firstMatch(data);
    if (waMatch != null) {
      String? w = waMatch.group(1);
      debugPrint('Regex wa_id: $w');
      if (w != null && w.isNotEmpty) {
        if (contactPhone.value.isEmpty) {
          contactPhone.value = w;
        }
        if (!contactPhones.contains(w)) {
          contactPhones.add(w);
        }
      }
    }

    debugPrint('Regex result - Name: ${contactName.value}, Phone: ${contactPhone.value}');
  }

  // Future<void> callContact() async {
  //   if (!hasPhone) {
  //     Get.snackbar('Error', 'No phone number available',
  //       snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.shade100);
  //     return;
  //   }
  //   final cleanPhone = contactPhone.value.replaceAll(' ', '');
  //   try {
  //     await launchUrl(Uri.parse('tel:$cleanPhone'));
  //   } catch (e) {
  //     debugPrint('Call error: $e');
  //   }
  // }

  // Future<void> openWhatsApp() async {
  //   if (!hasPhone) {
  //     Get.snackbar('Error', 'No phone number available',
  //       snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.red.shade100);
  //     return;
  //   }
  //   String cleanPhone = contactPhone.value.replaceAll(RegExp(r'[^\d]'), '');
  //   try {
  //     await launchUrl(Uri.parse('https://wa.me/$cleanPhone'), mode: LaunchMode.externalApplication);
  //   } catch (e) {
  //     debugPrint('WhatsApp error: $e');
  //   }
  // }

  Future<void> sendSms() async {
    if (!hasPhone) return;
    try {
      await launchUrl(Uri.parse('sms:${contactPhone.value.replaceAll(' ', '')}'));
    } catch (e) {
      debugPrint('SMS error: $e');
    }
  }

  Future<void> copyToClipboard() async {
    if (!hasPhone) return;
    await Clipboard.setData(ClipboardData(text: contactPhone.value));
    
  }

  // void showContactOptions() {
  //   Get.bottomSheet(
  //     Container(
  //       padding: const EdgeInsets.all(16),
  //       decoration: const BoxDecoration(
  //         color: Colors.white,
  //         borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  //       ),
  //       // child: Column(
  //       //   mainAxisSize: MainAxisSize.min,
  //       //   children: [
  //       //     Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 16),
  //       //       decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
  //       //     Text(contactName.value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
  //       //     const SizedBox(height: 16),
  //       //   //   if (hasPhone) ...[
  //       //   //     // _tile(Icons.call, 'Call', contactPhone.value, callContact),
  //       //   //     // _tile(Icons.message, 'WhatsApp', 'Send message', openWhatsApp),
  //       //   //     _tile(Icons.sms, 'SMS', 'Send text', sendSms),
  //       //   //     _tile(Icons.copy, 'Copy', contactPhone.value, copyToClipboard),
  //       //   //   ] else
  //       //   //     const Padding(padding: EdgeInsets.all(16), child: Text('No phone number')),
  //       //   //   const SizedBox(height: 8),
  //       //   ],
  //       // )
  //     ),
  //   );
  // }

  Widget _tile(IconData icon, String title, String sub, VoidCallback onTap) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: Colors.teal.shade50, child: Icon(icon, color: Colors.teal.shade600)),
      title: Text(title), subtitle: Text(sub),
      onTap: () { Get.back(); onTap(); },
    );
  }
}