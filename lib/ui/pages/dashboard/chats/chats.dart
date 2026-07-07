import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:getgabs/domain/controllers/dashboard/dashboard_controller.dart';
import 'package:getgabs/ui/pages/dashboard/chats/add_customer_dialog.dart';
import 'package:getgabs/ui/pages/dashboard/chats/active_chats/active_chats.dart';
import 'package:getgabs/ui/pages/dashboard/chats/rolling_over_chats.dart/rolling_over_chats.dart';
import 'package:getgabs/ui/res/assets/image_assets.dart';
import 'package:getgabs/ui/themes/themes.dart';

import '../../../res/widgets/custom_calendar.dart';

class ChatsScreen extends StatelessWidget {
  ChatsScreen({super.key});

  final DashboardController dashboardController =
      Get.put(DashboardController());

  @override
  Widget build(BuildContext context) {
    var mediaQuery = MediaQuery.of(context).size;
    return SafeArea(
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(100), // adjust height as needed
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chats',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  height: 45,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Obx(() => TextField(
                        focusNode: dashboardController.focusNode,
                        controller: dashboardController.searchEditingController.value,
                        onTap: () {
                          dashboardController.isSearching.value = false;
                        },
                        onTapOutside: (event) {
                          dashboardController.focusNode.unfocus();
                        },
                        onSubmitted: (value) {
                          print("Submitted");
                        },
                        onChanged: (value) async {
                            dashboardController.isSearching.value = true;

                            /// search API
                            dashboardController.onSearchChanged(value);
                        },
                        // onChanged: (value) {
                        //   if (value.isEmpty) {
                        //     dashboardController.searchCurrentPage.value = 0;
                        //     dashboardController.isSearching.value = false;
                        //   }else {
                        //     dashboardController.isSearching.value = true;
                        //   }

                        //   if (dashboardController.tabBarIndex == 0) {
                        //     dashboardController.activeProfileDetailsList.clear();
                        //     dashboardController.currentPage.value = 1;
                        //     dashboardController.searchCustomer(value);
                        //   } else {
                        //     dashboardController.rollingOverProfileDetailsList.clear();
                        //     dashboardController.searchCustomer(
                        //       value,
                        //       sessionType: 'close',
                        //       barIndex: 1,
                        //     );
                        //   }
                        // },
                        decoration: InputDecoration(
                          hintText: "Search chats...",
                          hintStyle: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                          prefixIcon: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12), // left-right space control
                            child: SvgPicture.asset(
                              ImageAssets.searchIcon,
                              color: Colors.grey.shade600,
                              width: 18,
                              height: 18,
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minHeight: 20,
                            minWidth: 20,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 8,
                          ),
                          // prefixIcon: const Icon(Icons.search),
                          suffixIcon: dashboardController.isSearching.value
                              ? Padding(
                                  padding: const EdgeInsets.only(right: 0),
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.close,
                                      size: 18, // 👈 icon size control
                                    ),
                                    padding: EdgeInsets.zero, // 👈 remove internal padding
                                    constraints: const BoxConstraints(
                                      minWidth: 28,   // 👈 reduce default 48px
                                      minHeight: 28,
                                    ),
                                    onPressed: () {
                                      dashboardController.searchEditingController.value.clear();
                                      dashboardController.focusNode.unfocus();

                                      if (dashboardController.tabBarIndex == 1) {
                                        dashboardController.refreshRollingOverChatList(
                                          increment: 'replace',
                                        );
                                      } else {
                                        dashboardController.refreshActiveChatList(
                                          increment: 'replace',
                                        );
                                      }
                                    },
                                  ),
                                )
                              : null,

                          suffixIconConstraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          border: InputBorder.none,
                        ),
                      )),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppTheme.appThemeColor,
          onPressed: () => showAddCustomerDialog(dashboardController),
          child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
        ),

        // appBar: AppBar(
        //   backgroundColor: AppTheme.whiteColor,
        //   automaticallyImplyLeading: false,
        //   flexibleSpace: Padding(
        //     padding: EdgeInsets.symmetric(horizontal: mediaQuery.width * 0.04),
        //     child: Row(
        //       children: [
        //         const Expanded(
        //           flex: 1, // Adjust the flex value as needed
        //           child: Text(
        //             'Chats',
        //             style: TextStyle(
        //               color: Colors.black,
        //               fontSize: 20,
        //               fontWeight: FontWeight.bold,
        //             ),
        //           ),
        //         ),
        //         Expanded(
        //           flex: 4, // Assign more space to the search field

        //           child: Container(
        //             padding: EdgeInsets.symmetric(
        //                 horizontal: mediaQuery.width * 0.010,
        //                 vertical: mediaQuery.height * 0.010),
        //             child: Obx(
        //               () => TextField(
        //                 focusNode: dashboardController.focusNode,
        //                 controller:
        //                     dashboardController.searchEditingController.value,
        //                 onChanged: (value) {
        //                   print("Editing Complete");
        //                   if (dashboardController
        //                           .searchEditingController.value.text ==
        //                       '') {
        //                     dashboardController.searchCurrentPage.value = 0;
        //                   }
        //                   if (dashboardController.tabBarIndex == 0) {
        //                     dashboardController.isApiCallInProgress.value =
        //                         false;
        //                     dashboardController.activeProfileDetailsList
        //                         .clear();
        //                     dashboardController.currentPage.value = 1;
        //                     dashboardController.searchCustomer(
        //                         dashboardController
        //                             .searchEditingController.value.text);
        //                   } else {
        //                     dashboardController.rollingOverProfileDetailsList
        //                         .clear();
        //                     dashboardController.searchCustomer(
        //                         dashboardController
        //                             .searchEditingController.value.text,
        //                         sessionType: 'close',
        //                         barIndex: 1);
        //                   }
        //                 },
        //                 decoration: InputDecoration(
        //                   hintText: 'Search for a message, a user…',
        //                   hintStyle: const TextStyle(
        //                       color: AppTheme.black54, fontSize: 13),
        //                   prefixIcon: IconButton(
        //                     icon: dashboardController.isSearching.value
        //                         ? Image.asset(ImageAssets
        //                             .reverseArrowPng) // If true, return an Icon WIDGET
        //                         : Image.asset(ImageAssets
        //                             .searchIconPng), // If false, return an Image WIDGET
        //                     color: AppTheme.greyColors,
        //                     onPressed: () {
        //                       dashboardController.searchEditingController.value
        //                           .clear();
        //                       dashboardController.isSearching.value = false;
        //                       dashboardController.focusNode.unfocus();
        //                       // FocusScope.of(context).unfocus();
        //                       if (dashboardController.tabBarIndex == 1) {
        //                         dashboardController.refreshRollingOverChatList(
        //                             increment: 'replace');
        //                       } else {
        //                         dashboardController.refreshActiveChatList(
        //                             increment: 'replace');
        //                       }
        //                     },
        //                   ),
        //                   filled: true,
        //                   fillColor: Colors.white,
        //                   border: OutlineInputBorder(
        //                     borderRadius: BorderRadius.circular(20.0),
        //                     borderSide: const BorderSide(
        //                       color: AppTheme.greyColor,
        //                     ),
        //                   ),
        //                   enabledBorder: OutlineInputBorder(
        //                     borderRadius: BorderRadius.circular(7.0),
        //                     borderSide: const BorderSide(
        //                       color: AppTheme.greyColor,
        //                     ),
        //                   ),
        //                   focusedBorder: const OutlineInputBorder(
        //                     // borderRadius: BorderRadius.circular(20.0),
        //                     borderSide: BorderSide(
        //                       color: AppTheme.boarderColor,
        //                     ),
        //                   ),
        //                   contentPadding:
        //                       const EdgeInsets.symmetric(vertical: 0.0),
        //                 ),
        //               ),
        //             ),
        //           ),
        //         ),
        //         // Expanded(
        //         //   flex: 1,
        //         //   child: Align(
        //         //     alignment: Alignment.centerRight,
        //         //     child: IconButton(
        //         //       icon: Image.asset(
        //         //         ImageAssets.filterIconPng,
        //         //         height: 24.0,
        //         //         width: 24.0,
        //         //       ),
        //         //       color: Colors.black,
        //         //       onPressed: () {
        //         //         showFiltersBottomSheet(context);
        //         //       },
        //         //     ),
        //         //   ),
        //         // ),
        //       ],
        //     ),
        //   ),
        // ),
        body: DefaultTabController(
          length: 2,
          child: Column(
            children: [

              // ── TabBar container ────────────────────────────────────────────────
              Container(
                color: AppTheme.whiteColor,
                padding: EdgeInsets.symmetric(
                  horizontal: mediaQuery.width * 0.04,
                  vertical:   mediaQuery.height * 0.01,
                ),
                child: Container(
                  height: mediaQuery.height * 0.050,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: TabBar(
                    dividerColor:          Colors.transparent,
                    indicatorSize:         TabBarIndicatorSize.tab,
                    labelColor:            Colors.white,
                    unselectedLabelColor:  Colors.black87,
                    labelStyle:   const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),

                    // ── Smooth animated indicator ──────────────────────────────
                    indicator: BoxDecoration(
                      color:        AppTheme.authButtonColor,
                      borderRadius: BorderRadius.circular(30),
                    ),

                    // ── Smooth label fade animation ────────────────────────────
                    splashFactory:       NoSplash.splashFactory,
                    overlayColor:        MaterialStateProperty.all(Colors.transparent),

                    tabs: const [
                      Tab(text: 'Active'),
                      Tab(text: 'Rolling Over'),
                    ],

                    onTap: (index) {
                      dashboardController.tabBarIndex = index;
                    },
                  ),
                ),
              ),

              // ── Tab content with fade+slide animation ───────────────────────────
              Expanded(
                child: _AnimatedTabView(
                  children: [
                    ActiveChats(),
                    RollingOverChats(),
                  ],
                ),
              ),
            ],
          ),
        ),
        // body: DefaultTabController(
        //   length: 2,
        //   child: Column(
        //     children: [

        //       /// 🔹 Modern Attractive TabBar
        //       Container(
        //         color: AppTheme.whiteColor,
        //         padding: EdgeInsets.symmetric(
        //           horizontal: mediaQuery.width * 0.04,
        //           vertical: mediaQuery.height * 0.01,
        //         ),
        //         child: Container(
        //           height: mediaQuery.height * 0.050,
        //           decoration: BoxDecoration(
        //             color: Colors.grey.shade200,
        //             borderRadius: BorderRadius.circular(30),
        //           ),
        //           child: TabBar(
        //             dividerColor: Colors.transparent,

        //             /// Selected Tab Design
        //             indicator: BoxDecoration(
        //               color: AppTheme.authButtonColor,
        //               borderRadius: BorderRadius.circular(30),
        //             ),

        //             indicatorSize: TabBarIndicatorSize.tab,

        //             /// Text colors
        //             labelColor: Colors.white,
        //             unselectedLabelColor: Colors.black87,

        //             /// Text styles
        //             labelStyle: const TextStyle(
        //               fontSize: 14,
        //               fontWeight: FontWeight.w600,
        //             ),
        //             unselectedLabelStyle: const TextStyle(
        //               fontSize: 14,
        //               fontWeight: FontWeight.w500,
        //             ),

        //             /// Tabs
        //             tabs: const [
        //               Tab(text: "Active"),
        //               Tab(text: "Rolling Over"),
        //             ],

        //             onTap: (index) {
        //               dashboardController.tabBarIndex = index;
        //             },
        //           ),
        //         ),
        //       ),

        //       /// 🔹 Tab Content
        //       Expanded(
        //         child: TabBarView(
        //           physics: const NeverScrollableScrollPhysics(),
        //           children: [
        //           ActiveChats(),
        //           RollingOverChats(),
        //           ],
        //         ),
        //       ),
        //     ],
        //   ),
        // ),
      ),
    );
  }
}

// // ─────────────────────────────────────────────────────────────────────────────
// //  ANIMATED TAB VIEW WIDGET
// //  — paste this class anywhere in the same file (outside build method)
// // ─────────────────────────────────────────────────────────────────────────────

// class _AnimatedTabView extends StatefulWidget {
//   final List<Widget> children;
//   const _AnimatedTabView({required this.children});

//   @override
//   State<_AnimatedTabView> createState() => _AnimatedTabViewState();
// }

// class _AnimatedTabViewState extends State<_AnimatedTabView>
//     with SingleTickerProviderStateMixin {

//   late final AnimationController _ctrl;
//   late final Animation<double>   _fade;
//   late final Animation<Offset>   _slide;

//   int _currentIndex = 0;
//   int _previousIndex = 0;

//   @override
//   void initState() {
//     super.initState();

//     _ctrl = AnimationController(
//       vsync:    this,
//       duration: const Duration(milliseconds: 320),
//     );

//     _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

//     _slide = Tween<Offset>(
//       begin: const Offset(0.06, 0),
//       end:   Offset.zero,
//     ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

//     _ctrl.forward();
//   }

//   @override
//   void dispose() {
//     _ctrl.dispose();
//     super.dispose();
//   }

//   void _onTabChanged(int index) {
//     if (index == _currentIndex) return;
//     setState(() {
//       _previousIndex = _currentIndex;
//       _currentIndex  = index;
//     });
//     _ctrl.forward(from: 0);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return TabControllerListener(
//       onTabChanged: _onTabChanged,
//       child: FadeTransition(
//         opacity: _fade,
//         child: SlideTransition(
//           position: _slide,
//           child: widget.children[_currentIndex],
//         ),
//       ),
//     );
//   }
// }


// // ─────────────────────────────────────────────────────────────────────────────
// //  TAB CONTROLLER LISTENER  — listens to DefaultTabController
// // ─────────────────────────────────────────────────────────────────────────────

// class TabControllerListener extends StatefulWidget {
//   final Widget child;
//   final void Function(int index) onTabChanged;

//   const TabControllerListener({
//     super.key,
//     required this.child,
//     required this.onTabChanged,
//   });

//   @override
//   State<TabControllerListener> createState() => _TabControllerListenerState();
// }

// class _TabControllerListenerState extends State<TabControllerListener> {
//   TabController? _tabController;

//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     _tabController?.removeListener(_handleTabChange);
//     _tabController = DefaultTabController.of(context);
//     _tabController?.addListener(_handleTabChange);
//   }

//   void _handleTabChange() {
//     if (_tabController == null) return;
//     if (!_tabController!.indexIsChanging) {
//       widget.onTabChanged(_tabController!.index);
//     }
//   }

//   @override
//   void dispose() {
//     _tabController?.removeListener(_handleTabChange);
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) => widget.child;
// }

// ─────────────────────────────────────────────────────────────────────────────
//  ADD THESE CLASSES IN YOUR FILE
// ─────────────────────────────────────────────────────────────────────────────

class _AnimatedTabView extends StatefulWidget {
  final List<Widget> children;
  const _AnimatedTabView({required this.children});

  @override
  State<_AnimatedTabView> createState() => _AnimatedTabViewState();
}

// ✅ TickerProviderStateMixin added — fixes the _ticker NoSuchMethodError
class _AnimatedTabViewState extends State<_AnimatedTabView>
    with TickerProviderStateMixin {

  int _current = 0;

  void _switchTo(int newIndex) {
    if (newIndex == _current) return;
    setState(() => _current = newIndex);
  }

  @override
  Widget build(BuildContext context) {
    return _TabListener(
      onTabChanged: _switchTo,
      child: AnimatedSwitcher(
        duration:        const Duration(milliseconds: 300),
        reverseDuration: const Duration(milliseconds: 200),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve:  Curves.easeInOut,
          ),
          child: child,
        ),
        child: KeyedSubtree(
          key:   ValueKey<int>(_current),
          child: widget.children[_current],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  TAB LISTENER
// ─────────────────────────────────────────────────────────────────────────────

class _TabListener extends StatefulWidget {
  final Widget child;
  final void Function(int) onTabChanged;

  const _TabListener({required this.child, required this.onTabChanged});

  @override
  State<_TabListener> createState() => _TabListenerState();
}

class _TabListenerState extends State<_TabListener> {
  TabController? _tabCtrl;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tabCtrl?.removeListener(_listen);
    _tabCtrl = DefaultTabController.of(context);
    _tabCtrl?.addListener(_listen);
  }

  void _listen() {
    if (_tabCtrl == null)          return;
    if (_tabCtrl!.indexIsChanging) return;
    widget.onTabChanged(_tabCtrl!.index);
  }

  @override
  void dispose() {
    _tabCtrl?.removeListener(_listen);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

void _showCalendar() {
  BuildContext context;
  Get.bottomSheet(
    Container(
      height: Get.height * 0.6,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      child: const CustomCalendar(), // Your reusable CustomCalendar widget
    ),
    isScrollControlled: true,
  );
}

void showFiltersBottomSheet(BuildContext context) {
  Get.bottomSheet(
    elevation: 0,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(12),
        topRight: Radius.circular(12),
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        height: MediaQuery.of(context).size.height * 0.5,
        width: MediaQuery.of(context).size.width * 0.90,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.05,
                  vertical: MediaQuery.of(context).size.height * 0.02,
                ),
                child: Text(
                  "Filters",
                  style: TextStyle(
                    color: AppTheme.blackColor,
                    fontSize: MediaQuery.of(context).size.width *
                        0.04, // Responsive font size
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Divider(color: Colors.grey[100]),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.04,
                ),
                child: ListTile(
                  title: Text(
                    'All Chats',
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width *
                          0.035, // Responsive font size
                      color: AppTheme.greyColors,
                    ),
                  ),
                ),
              ),
              Divider(color: Colors.grey[100]),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.04,
                ),
                child: ListTile(
                  title: Text(
                    'Unread',
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width *
                          0.035, // Responsive font size
                    ),
                  ),
                ),
              ),
              Divider(color: Colors.grey[100]),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.04,
                ),
                child: ListTile(
                  title: Text(
                    'Favorite',
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width *
                          0.035, // Responsive font size
                    ),
                  ),
                ),
              ),
              Divider(color: Colors.grey[100]),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.04,
                ),
                child: ListTile(
                  title: Text(
                    'By Date',
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width *
                          0.035, // Responsive font size
                    ),
                  ),
                  onTap: () {
                    Get.back();
                    _showCalendar();
                  },
                ),
              ),
              Divider(color: Colors.grey[100]),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.04,
                ),
                child: ListTile(
                  title: Text(
                    'By Tags',
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width *
                          0.035, // Responsive font size
                    ),
                  ),
                  onTap: () {
                    Get.back();
                    _showTags(context); // Pass context here
                  },
                ),
              ),
              Divider(color: Colors.grey[100]),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width * 0.04,
                ),
                child: ListTile(
                  title: Text(
                    'Blocked',
                    style: TextStyle(
                      fontSize: MediaQuery.of(context).size.width *
                          0.035, // Responsive font size
                    ),
                  ),
                  onTap: () {},
                ),
              ),
              Divider(color: Colors.grey[100]),
              Center(
                child: TextButton(
                    onPressed: () {
                      Get.back();
                    },
                    child: const Text(
                      "Cancel",
                      style: TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.w400),
                    )),
              )
            ],
          ),
        ),
      ),
    ),
  );
}

void _showTags(BuildContext context) {
  Get.bottomSheet(
    ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(12),
        topRight: Radius.circular(12),
      ),
      child: Container(
        padding: EdgeInsets.all(
            MediaQuery.of(context).size.width * 0.05), // Responsive padding
        decoration: const BoxDecoration(
            // color: Colors.white,
            ),
        child: Card(
          elevation: 8,
          shadowColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width * 0.03,
              vertical: MediaQuery.of(context).size.height * 0.02,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width * 0.05,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select tags',
                        style: TextStyle(
                          fontSize: MediaQuery.of(context).size.width *
                              0.04, // Responsive font size
                          fontWeight: FontWeight.bold,
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
                // List of tags with checkboxes
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width * 0.03,
                  ),
                  child: CheckboxTheme(
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
                          fontSize: MediaQuery.of(context).size.width *
                              0.035, // Responsive font size
                        ),
                      ),
                      value: false,
                      onChanged: (value) {},
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width * 0.03,
                  ),
                  child: CheckboxTheme(
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
                          fontSize: MediaQuery.of(context).size.width *
                              0.035, // Responsive font size
                        ),
                      ),
                      value: false,
                      onChanged: (value) {},
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width * 0.03,
                  ),
                  child: CheckboxTheme(
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
                          fontSize: MediaQuery.of(context).size.width *
                              0.035, // Responsive font size
                        ),
                      ),
                      value: false,
                      onChanged: (value) {},
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width * 0.03,
                  ),
                  child: CheckboxTheme(
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
                          fontSize: MediaQuery.of(context).size.width *
                              0.035, // Responsive font size
                        ),
                      ),
                      value: false,
                      onChanged: (value) {},
                    ),
                  ),
                ),
                const SizedBox(height: 80),
                Divider(color: Colors.grey[300]),

                Center(
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.appThemeColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width *
                            0.1, // Responsive padding
                        vertical: MediaQuery.of(context).size.height *
                            0.01, // Responsive padding
                      ),
                    ),
                    child: Text(
                      'Find',
                      style: TextStyle(
                        fontSize: MediaQuery.of(context).size.width *
                            0.04, // Responsive font size
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    isScrollControlled: true,
  );
}
