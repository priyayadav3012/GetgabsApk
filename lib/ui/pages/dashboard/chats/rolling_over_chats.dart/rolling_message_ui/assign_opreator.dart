import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getgabs/ui/themes/themes.dart';

class OperatorController extends GetxController {
  var isSearching = false.obs;
  final FocusNode focusNode = FocusNode();
  var selectedIndex = (-1).obs;
  final TextEditingController searchController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    // Listen to focus changes
    focusNode.addListener(() {
      if (focusNode.hasFocus) {
        isSearching.value = true;  
      } else {
        isSearching.value = false;
      }
    });
  }

  void selectOperator(int index) {
    selectedIndex.value = index;
  }

  void clearSearch() {
    searchController.clear();
    isSearching.value = false;
    focusNode.unfocus(); 
  }

  @override
  void onClose() {
    focusNode.dispose();
    searchController.dispose();
    super.onClose();
  }
}

class AssignOperatorScreen extends StatelessWidget {
  final OperatorController controller = Get.put(OperatorController());

   AssignOperatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Choose an Operator to assign",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                padding: const EdgeInsets.symmetric(horizontal: 0.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 1, // Adds more space around the shadow
                      offset: const Offset(3, 4),
                    ),
                  ],
                ),
                child: Obx(
                  () => TextField(
                    focusNode: controller.focusNode,
                    controller: controller.searchController,
                    decoration: InputDecoration(
                      hintText: 'Search Operators...',
                      hintStyle:
                          const TextStyle(color: AppTheme.black54, fontSize: 13),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: controller.isSearching.value
                            ? GestureDetector(
                                onTap: () {
                                  controller.clearSearch();
                                },
                                child: Image.asset('assets/images/arrow-back.png'),
                              )
                            : Image.asset('assets/images/assign-search.png'),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.0),
                        borderSide: const BorderSide(
                          color: Colors.white,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: AppTheme.boarderColor,
                        ),
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 0.0),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16.0),

            // Operators List
            Expanded(
              child: ListView.builder(
                itemCount: 5,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      children: [
                        Obx(() {
                          bool isSelected = controller.selectedIndex.value == index;
                          return ListTile(
                            onTap: () {
                              controller.selectOperator(index);
                            },
                            leading: const CircleAvatar(
                              radius: 24,
                              backgroundImage:
                                  AssetImage('assets/images/assign-profile.png'),
                            ),
                            title: const Text('Savitri Mahaseth',style: TextStyle(fontSize: 16),),
                            subtitle: const Text('Sales Executive',style: TextStyle(fontSize: 13,color: AppTheme.greyColor),),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected) ...[
                                  const Icon(
                                    Icons.circle,
                                    color: AppTheme.daysColor,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    onPressed: () {
                                      
                                      
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.appThemeColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(28),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 30,
                                        vertical: 10,
                                      ),
                                    ),
                                    child: const Text(
                                      'Assign',
                                      style: TextStyle(
                                          fontSize: 16, color: Colors.white),
                                    ),
                                  ),
                                ] else ...[
                                  const Icon(
                                    Icons.circle,
                                    color: AppTheme.daysColor,
                                    size: 12,
                                  ),
                                ]
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
