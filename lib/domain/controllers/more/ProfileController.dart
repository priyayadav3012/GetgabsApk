import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getgabs/data/get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../../data/models/profile_detail_model.dart';
import '../../../ui/res/widgets/customDailogBox/customdailog.dart';
import '../../services/remote_services/profile_service.dart';

class ProfileController extends GetxController {
  final GetStorageUserData userData = GetStorageUserData();
  final ProfileServices _profileServices = ProfileServices();
  final ImagePicker _picker = ImagePicker();

  // Ordered day keys (API uses lowercase full names, e.g. "monday").
  static const List<String> dayKeys = [
    'sunday',
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
  ];

  // Static option lists for fields the API has no lookup for.
  static const List<String> languageOptions = [
    'English',
    'Hindi',
    'Spanish',
    'French',
    'Arabic',
    'Portuguese',
    'German',
    'Chinese',
  ];

  // ---- Legacy observables still read by more_screen.dart ----
  var userName = ' '.obs;
  var email = ' '.obs;
  var phoneNumber = ' '.obs;
  var role = ' '.obs;

  // ---- Loading / saving state ----
  var isLoading = true.obs;
  var isSaving = false.obs;

  // Working Hours is collapsed by default; user taps the header to expand it.
  var workingHoursExpanded = false.obs;

  // ---- Read-only, from server ----
  final RxInt profileId = 0.obs;
  final RxString roleRaw = ''.obs; // raw role string (user/sub-user/...)
  final RxnString profileImageUrl = RxnString();

  // ---- Editable form fields ----
  final TextEditingController nameController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final RxString selectedCountryCode = ''.obs; // display, e.g. "India (+91)"
  final RxString selectedLocation = ''.obs;
  final RxString selectedTimezone = ''.obs; // timeZone value, e.g. "Asia/Kolkata"
  final RxString selectedLanguage = ''.obs;

  // Locally-picked image (not yet uploaded).
  final RxnString pickedImagePath = RxnString();

  // Working hours: day -> list of slots. Empty list = day disabled.
  final RxMap<String, List<WorkingHoursSlot>> workingHours =
      <String, List<WorkingHoursSlot>>{}.obs;

  // Dropdown data.
  final RxList<CountryCodeItem> countryCodes = <CountryCodeItem>[].obs;
  final RxList<TimezoneItem> timezones = <TimezoneItem>[].obs;
  final RxList<String> locationOptions = <String>[].obs;

  // Snapshot of the last-fetched profile, used by Reset.
  ProfileDetail? _lastFetched;

  @override
  void onInit() {
    super.onInit();
    for (final d in dayKeys) {
      workingHours[d] = <WorkingHoursSlot>[];
    }
    _loadLocalBasics(); // instant values for more_screen's header
    fetchProfileApi(); // authoritative data for the profile screen
  }

  /// Populates the legacy observables from locally-cached login data so
  /// more_screen's avatar/name/email render instantly, even before (or without)
  /// the network fetch.
  Future<void> _loadLocalBasics() async {
    try {
      final value = await userData.getUserDataInOneShot();
      if (value == null) return;
      userName.value = value['name']?.toString() ?? userName.value;
      email.value = value['email']?.toString() ?? email.value;
      phoneNumber.value = value['phone']?.toString() ?? phoneNumber.value;
      role.value = _displayRole(value['role']?.toString() ?? '');
    } catch (e) {
      debugPrint('⚠️ _loadLocalBasics error: $e');
    }
  }

  @override
  void onClose() {
    nameController.dispose();
    contactController.dispose();
    super.onClose();
  }

  // ---------------------------------------------------------------------------
  // Auth params common to both endpoints.
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>> _authParams() async {
    final currentUserId = await userData.getLoggedInUserId();
    final parentIdStr = await userData.getParentUserId();
    final currentUserRole = await userData.getUserRole();
    final userPrivilage = await userData.getUserPrivilage();
    final apiKey = await userData.getApiKey();
    return {
      'current_user_id': currentUserId,
      'parent_user_id': int.tryParse(parentIdStr) ?? 0,
      'current_user_role': currentUserRole,
      'user_privilage': userPrivilage,
      'api_key': apiKey,
    };
  }

  // ---------------------------------------------------------------------------
  // Fetch
  // ---------------------------------------------------------------------------
  Future<void> fetchProfileApi() async {
    try {
      isLoading.value = true;
      final auth = await _authParams();
      final apiKey = auth['api_key']?.toString() ?? '';

      final headers = {
        'x-client-getgabs': apiKey,
        'Content-Type': 'application/json',
      };

      final value = await _profileServices.fetchProfile(auth, headers: headers);

      if (value == null || value['status'] != true) {
        debugPrint('❌ fetchProfile failed: $value');
        return;
      }

      final data = value['message']?['data'];
      if (data != null) {
        final profile = ProfileDetail.fromJson(Map<String, dynamic>.from(data));
        _applyProfile(profile);
      }

      countryCodes.assignAll(((value['countryCodes'] as List?) ?? [])
          .map((e) => CountryCodeItem.fromJson(Map<String, dynamic>.from(e)))
          .toList());
      timezones.assignAll(((value['timezones'] as List?) ?? [])
          .map((e) => TimezoneItem.fromJson(Map<String, dynamic>.from(e)))
          .toList());

      // Location options: derive from the country names we already have, plus
      // whatever the profile currently holds (so the saved value is selectable).
      final locs = <String>{
        for (final c in countryCodes) c.countryName,
        if (selectedLocation.value.isNotEmpty) selectedLocation.value,
      }..removeWhere((e) => e.trim().isEmpty);
      locationOptions.assignAll(locs.toList()..sort());
    } catch (e, st) {
      debugPrint('❌ fetchProfileApi error: $e\n$st');
    } finally {
      isLoading.value = false;
    }
  }

  void _applyProfile(ProfileDetail p) {
    _lastFetched = p;

    profileId.value = p.id;
    roleRaw.value = p.role;
    profileImageUrl.value = p.profileImageUrl;
    pickedImagePath.value = null;

    nameController.text = p.name;
    contactController.text = p.contactNumber;
    selectedCountryCode.value = p.countryCode;
    selectedLocation.value = p.location;
    selectedTimezone.value = p.timezone;
    selectedLanguage.value = p.language;

    _parseWorkingHours(p.workingHours);

    // Legacy observables for more_screen.
    userName.value = p.name;
    email.value = p.email;
    phoneNumber.value = p.phone;
    role.value = _displayRole(p.role);
  }

  String _displayRole(String raw) {
    switch (raw) {
      case 'user':
        return 'Admin';
      case 'sub-user':
        return 'Executive';
      case 'manager':
        return 'Manager';
      default:
        return raw.isEmpty ? 'Member' : raw;
    }
  }

  String get displayEmail => email.value.trim();
  String get displayRole => role.value.trim();

  // ---------------------------------------------------------------------------
  // Working hours helpers
  // ---------------------------------------------------------------------------
  void _parseWorkingHours(String raw) {
    for (final d in dayKeys) {
      workingHours[d] = <WorkingHoursSlot>[];
    }
    if (raw.trim().isEmpty) {
      workingHours.refresh();
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        decoded.forEach((key, value) {
          final day = key.toString().toLowerCase();
          if (dayKeys.contains(day) && value is List) {
            workingHours[day] = value
                .map((e) => WorkingHoursSlot.fromJson(Map<String, dynamic>.from(e)))
                .toList();
          }
        });
      }
    } catch (e) {
      debugPrint('⚠️ working_hours parse error: $e');
    }
    workingHours.refresh();
  }

  bool isDayEnabled(String day) => (workingHours[day] ?? []).isNotEmpty;

  void toggleDay(String day, bool enabled) {
    if (enabled) {
      if ((workingHours[day] ?? []).isEmpty) {
        workingHours[day] = [WorkingHoursSlot(from: '09:00', to: '18:00')];
      }
    } else {
      workingHours[day] = <WorkingHoursSlot>[];
    }
    workingHours.refresh();
  }

  void addSlot(String day) {
    final list = workingHours[day] ?? <WorkingHoursSlot>[];
    list.add(WorkingHoursSlot(from: '09:00', to: '18:00'));
    workingHours[day] = list;
    workingHours.refresh();
  }

  void removeSlot(String day, int index) {
    final list = workingHours[day] ?? <WorkingHoursSlot>[];
    if (index >= 0 && index < list.length) {
      list.removeAt(index);
      workingHours[day] = list;
      workingHours.refresh();
    }
  }

  void setSlotTime(String day, int index, {String? from, String? to}) {
    final list = workingHours[day] ?? <WorkingHoursSlot>[];
    if (index >= 0 && index < list.length) {
      if (from != null) list[index].from = from;
      if (to != null) list[index].to = to;
      workingHours[day] = list;
      workingHours.refresh();
    }
  }

  String _buildWorkingHoursJson() {
    final map = <String, List<Map<String, String>>>{};
    for (final d in dayKeys) {
      final slots = workingHours[d] ?? [];
      if (slots.isNotEmpty) {
        map[d] = slots.map((s) => s.toJson()).toList();
      }
    }
    return jsonEncode(map);
  }

  // ---------------------------------------------------------------------------
  // Photo
  // ---------------------------------------------------------------------------
  Future<void> pickImage() async {
    try {
      final XFile? file =
          await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file == null) return;

      final bytes = await File(file.path).length();
      if (bytes > 2 * 1024 * 1024) {
        Get.snackbar('Too large', 'Profile photo must be 2 MB or smaller.',
            snackPosition: SnackPosition.BOTTOM);
        return;
      }
      pickedImagePath.value = file.path;
    } catch (e) {
      debugPrint('❌ pickImage error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Save / Reset
  // ---------------------------------------------------------------------------
  Future<void> saveProfile() async {
    if (isSaving.value) return;

    if (nameController.text.trim().isEmpty) {
      Get.snackbar('Required', 'Full name cannot be empty.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (contactController.text.trim().isEmpty) {
      Get.snackbar('Required', 'Contact number cannot be empty.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    try {
      isSaving.value = true;
      final auth = await _authParams();
      final apiKey = auth['api_key']?.toString() ?? '';

      final fields = <String, String>{
        'current_user_id': auth['current_user_id'].toString(),
        'parent_user_id': auth['parent_user_id'].toString(),
        'current_user_role': auth['current_user_role'].toString(),
        'user_privilage': auth['user_privilage'].toString(),
        'api_key': apiKey,
        'name': nameController.text.trim(),
        'contact_number': contactController.text.trim(),
        'country_code': selectedCountryCode.value,
        'timezone': selectedTimezone.value,
        'location': selectedLocation.value,
        'language': selectedLanguage.value,
        'working_hours': _buildWorkingHoursJson(),
      };

      final value = await _profileServices.updateProfile(
        fields,
        apiKey: apiKey,
        imagePath: pickedImagePath.value,
      );

      if (value != null && value['status'] == true) {
        final data = value['data'];
        if (data != null) {
          _applyProfile(ProfileDetail.fromJson(Map<String, dynamic>.from(data)));
        }
        pickedImagePath.value = null;
        Get.snackbar('Saved', 'Profile updated successfully',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFF2196F3),
            colorText: const Color(0xFFFFFFFF));
      } else {
        final msg = value?['message']?.toString() ?? 'Failed to update profile.';
        Get.snackbar('Error', msg, snackPosition: SnackPosition.BOTTOM);
      }
    } catch (e) {
      debugPrint('❌ saveProfile error: $e');
      Get.snackbar('Error', 'Something went wrong. Please try again.',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      isSaving.value = false;
    }
  }

  /// Reverts every field to the last successfully-fetched profile.
  void resetForm() {
    final p = _lastFetched;
    if (p != null) {
      _applyProfile(p);
    }
    pickedImagePath.value = null;
  }

  // ---------------------------------------------------------------------------
  // Legacy navigation helpers (kept from the old screen)
  // ---------------------------------------------------------------------------
  void navigateToChangePassword() {
    Get.toNamed('/change-password');
  }

  void confirmDeleteAccount() {
    Get.generalDialog(
      barrierDismissible: false,
      barrierLabel: "Delete Account",
      pageBuilder: (context, __, ___) {
        return CustomDialog(
          title: "Are you sure you want to delete your account?",
          yesButtonText: "Yes",
          noButtonText: "No",
          onYesPressed: () => Get.back(),
          onNoPressed: () => Get.back(),
        );
      },
      transitionDuration: const Duration(milliseconds: 800),
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -1),
            end: const Offset(0, 0),
          ).animate(anim1),
          child: child,
        );
      },
    );
  }
}
