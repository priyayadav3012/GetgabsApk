import 'package:flutter/material.dart';
import 'package:get/get.dart';

// Define a function to create the bottom sheet
Widget buildAddTagsBottomSheet() {
  return Padding(
    padding: const EdgeInsets.only(
      top: 20.0, 
      bottom: 100.0,
    ),
    child: ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(12),
        topRight: Radius.circular(12),
      ),
      child: Container(
        padding: const EdgeInsets.all(40),
        child: LayoutBuilder(
          builder: (context, constraints) {
            var mediaQuery = MediaQuery.of(context).size;
            return Card(
              elevation: 8,
              shadowColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: mediaQuery.width * 0.08,
                        vertical: mediaQuery.height * 0.01
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Add tags',
                            style: TextStyle(
                              fontSize: mediaQuery.width * 0.04,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              Get.back(); 
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    Divider(color: Colors.grey[300]), 
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: mediaQuery.width * 0.05,
                      ),
                      child: Column(
                        children: [
                          CheckboxTheme(
                            data: CheckboxThemeData(
                              side: const BorderSide(color: Colors.grey), 
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: CheckboxListTile(
                              title: Text(
                                'API',
                                style: TextStyle(
                                  fontSize: mediaQuery.width * 0.04,
                                ),
                              ),
                              value: false,
                              onChanged: (value) {},
                            ),
                          ),
                          CheckboxTheme(
                            data: CheckboxThemeData(
                              side: const BorderSide(color: Colors.grey), 
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: CheckboxListTile(
                              title: Text(
                                'General Enquiry',
                                style: TextStyle(
                                  fontSize: mediaQuery.width * 0.04,
                                ),
                              ),
                              value: false,
                              onChanged: (value) {},
                            ),
                          ),
                          CheckboxTheme(
                            data: CheckboxThemeData(
                              side: const BorderSide(color: Colors.grey), 
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: CheckboxListTile(
                              title: Text(
                                'Appointment',
                                style: TextStyle(
                                  fontSize: mediaQuery.width * 0.04,
                                ),
                              ),
                              value: false,
                              onChanged: (value) {},
                            ),
                          ),
                          CheckboxTheme(
                            data: CheckboxThemeData(
                              side: const BorderSide(color: Colors.grey), 
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: CheckboxListTile(
                              title: Text(
                                'Price Negotiation',
                                style: TextStyle(
                                  fontSize: mediaQuery.width * 0.04,
                                ),
                              ),
                              value: false,
                              onChanged: (value) {},
                            ),
                          ),
                        ],
                      ),
                    ),
              
                    SizedBox(height: mediaQuery.height * 0.05),
                    
                   
                    Center(
                      child: Text(
                        '+ Add Tags',
                        style: TextStyle(
                          fontSize: mediaQuery.width * 0.040,
                          color: Colors.blue,
                        ),
                      ),
                    ),
              
                    SizedBox(height: mediaQuery.height * 0.05), 
              
                    Divider(color: Colors.grey[300]),
                    SizedBox(height: mediaQuery.height * 0.03), 
                    Padding(
                      padding: EdgeInsets.only(right: mediaQuery.width * 0.04),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end, 
                        children: [
                          TextButton(
                            onPressed: () { 
                              Get.back();
                             },
                            child: Text(
                              'Save',
                              style: TextStyle(
                                fontSize: mediaQuery.width * 0.040,
                                color: Colors.blue,
                              ),
                              
                            ),
                          ),
                          
                        ],
                      ),
                    ),
              
                    SizedBox(height: mediaQuery.height * 0.03), // Final spacing before the end
                  ],
                ),
              
            );
          },
        ),
      ),
    ),
  );
}

// Function to show the bottom sheet
void showAddTagsBottomSheet() {
  Get.bottomSheet(
    buildAddTagsBottomSheet(),
    isScrollControlled: true,
  );
}
