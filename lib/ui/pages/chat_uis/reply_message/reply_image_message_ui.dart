import 'dart:io';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:getgabs/ui/pages/chat_uis/reply_message/reply_base_message_ui.dart';

class ImageController extends GetxController {
  final String imageUrl;

  ImageController(this.imageUrl);
}

class ReplyImageMessageUi extends StatelessWidget {
  final String? imageUrl; // Nullable for local image paths
  final File? imageFile;  // For local file images
  
 
  final Size mediaQuery;
  
  
  final String caption;

  const ReplyImageMessageUi({super.key, 
    this.imageUrl,
    this.imageFile,
    
   
    required this.mediaQuery,
   
    
    required this.caption, required messageType
  });

  @override
  Widget build(BuildContext context) {
    return 
    ReplyBaseMessageUi(
     
      
      mediaQuery: mediaQuery,
      
      child: Center(
        child: GetBuilder<ImageController>(
          init: ImageController(imageUrl ?? ''),
          global: false,
          builder: (controller) {
            if (imageFile != null) {
              // For local images
              return _buildImageWidget(Image.file(imageFile!, fit: BoxFit.cover),context);
            } else {
              // For network images
              return _buildImageWithCaption(CachedNetworkImage(
                imageUrl: controller.imageUrl,
                placeholder: (context, url) => _buildBlurredImage(url),
                errorWidget: (context, url, error) => const Icon(Icons.error),
                fit: BoxFit.cover,
                
                
              ),context);
            }
          },
        ),
      ),
    );
  }
 Widget _buildImageWithCaption(Widget image,BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildImageWidget(image,context),
        if (caption.isNotEmpty) 
          const SizedBox(height: 8.0), 
        if (caption.isNotEmpty)
          
              Text(
                caption, 
                style: const TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87, 
                ),
              ),
              
                                                                                       
      ],
    );
  }
  Widget _buildImageWidget(Widget image,BuildContext context) {
    return SizedBox(
      height:MediaQuery.of(context).size.height*0.095,
       
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
      topLeft: Radius.circular(8.0),
      topRight: Radius.circular(8.0),
    ),
        child: SizedBox(
         width: mediaQuery.width * 0.2, // Adjusted width to be slightly smaller
      
          height: mediaQuery.height * 0.05,  // Adjust the height as needed
          child: image,
        ),
      ),
    );
  }

  Widget _buildBlurredImage(String url) {
    return FutureBuilder(
      future: _loadImage(url),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
          return ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Image.memory(
              snapshot.data as Uint8List,
              fit: BoxFit.cover,
              colorBlendMode: BlendMode.darken,
              color: Colors.black.withOpacity(0.3),
            ),
          );
        } else {
          return Container(
            height: 200,
            color: Colors.grey,
            // child: Center(child: CircularProgressIndicator()),
          );
        }
      },
    );
  }

  Future<Uint8List> _loadImage(String url) async {
    final response = await NetworkAssetBundle(Uri.parse(url)).load(url);
    return response.buffer.asUint8List();
  }
}
