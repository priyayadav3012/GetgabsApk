import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:getgabs/ui/pages/chat_uis/base_message_ui.dart';

class LocationMessageUi extends StatelessWidget {
  final String location;
  final bool isSentByMe;
  final DateTime createdAt;
  final Size mediaQuery;
  final String deliveryStatus;

  const LocationMessageUi({
    super.key,
    required this.location,
    required this.isSentByMe,
    required this.createdAt,
    required this.mediaQuery,
    required this.deliveryStatus,
  });

  @override
  Widget build(BuildContext context) {
    // Parse JSON location string
    // Map<String, dynamic> locationData = jsonDecode(location);
    // double latitude = locationData['lat'];
    // double longitude = locationData['long'];
Map<String, dynamic> locationData = jsonDecode(location);

double? parseToDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

double latitude = 0.0;
double longitude = 0.0;

double? lat = parseToDouble(locationData['lat'] ?? locationData['latitude']);
double? long = parseToDouble(locationData['long'] ?? locationData['longitude']);

if (lat != null && long != null) {
  latitude = lat;
  longitude = long;
} else {
  return Text(''); // Or handle the error accordingly
}


    return BaseMessageUi(
      isSentByMe: isSentByMe,
      createdAt: createdAt,
      mediaQuery: mediaQuery,
      deliveryStatus: deliveryStatus,
      child: GestureDetector(
        onTap: () => openGoogleMaps(latitude, longitude),
        child: Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blueAccent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on, color: Colors.white),
              SizedBox(width: 5),
              Text(
                "View Location",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void openGoogleMaps(double lat, double long) async {
    final url = "https://www.google.com/maps/search/?api=1&query=$lat,$long";
    var uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw "Could not open Google Maps.";
    }
  }
}
