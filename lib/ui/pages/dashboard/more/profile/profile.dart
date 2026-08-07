import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:getgabs/ui/themes/themes.dart';

import '../../../../../data/models/profile_detail_model.dart';
import '../../../../../domain/controllers/more/ProfileController.dart';

class ProfileScreen extends StatelessWidget {
  final ProfileController controller = Get.find<ProfileController>();

  ProfileScreen({super.key});

  Color get _accent => AppTheme.appThemeColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('My Profile',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.15),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return Center(child: CircularProgressIndicator(color: _accent));
        }
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 10),
                      child: Text(
                        'Manage your personal account details and preferences',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                    _personalInfoCard(context),
                    const SizedBox(height: 14),
                    _preferencesCard(context),
                    const SizedBox(height: 90),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
      bottomNavigationBar: Obx(() => _bottomBar(controller.isSaving.value)),
    );
  }

  // ===========================================================================
  // Personal Information
  // ===========================================================================
  Widget _personalInfoCard(BuildContext context) {
    return _card(
      icon: Icons.person_outline,
      title: 'Personal Information',
      subtitle: 'Your name, email and contact details.',
      children: [
        _photoRow(),
        const SizedBox(height: 18),
        _fieldLabel('Full Name', required: true),
        TextField(
          controller: controller.nameController,
          decoration: _inputDecoration(hint: 'Enter your name'),
        ),
        const SizedBox(height: 16),
        _fieldLabel('Email Address', readOnly: true),
        Obx(() => TextField(
              enabled: false,
              controller: TextEditingController(text: controller.displayEmail),
              decoration: _inputDecoration(hint: '—').copyWith(
                fillColor: const Color(0xFFF0F2F5),
                filled: true,
              ),
            )),
        const SizedBox(height: 16),
        _fieldLabel('Contact Number', required: true),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Obx(() => _dropdown(
                    value: _presentValue(
                      controller.selectedCountryCode.value,
                      controller.countryCodes.map((e) => e.display).toList(),
                    ),
                    items: _withCurrent(
                      controller.countryCodes.map((e) => e.display).toList(),
                      controller.selectedCountryCode.value,
                    ),
                    hint: 'Code',
                    onChanged: (v) =>
                        controller.selectedCountryCode.value = v ?? '',
                  )),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller.contactController,
                keyboardType: TextInputType.phone,
                decoration: _inputDecoration(hint: 'Phone number'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _fieldLabel('Location'),
        Obx(() => _dropdown(
              value: _presentValue(
                  controller.selectedLocation.value, controller.locationOptions),
              items: _withCurrent(
                  controller.locationOptions, controller.selectedLocation.value),
              hint: 'Select your location',
              onChanged: (v) => controller.selectedLocation.value = v ?? '',
            )),
      ],
    );
  }

  Widget _photoRow() {
    return Row(
      children: [
        Obx(() {
          final picked = controller.pickedImagePath.value;
          final url = controller.profileImageUrl.value;
          ImageProvider? img;
          if (picked != null && picked.isNotEmpty) {
            img = FileImage(File(picked));
          } else if (url != null && url.isNotEmpty) {
            img = NetworkImage(url);
          }
          return CircleAvatar(
            radius: 30,
            backgroundColor: _accent.withOpacity(0.15),
            backgroundImage: img,
            child: img == null
                ? Text(
                    _initials(controller.nameController.text),
                    style: TextStyle(
                        color: _accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 20),
                  )
                : null,
          );
        }),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Profile Photo',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 2),
              Text('JPG, PNG, GIF · Max 2 MB',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: controller.pickImage,
                icon: const Icon(Icons.upload_outlined, size: 18),
                label: const Text('Upload Photo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _accent,
                  side: BorderSide(color: _accent.withOpacity(0.5)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Preferences
  // ===========================================================================
  Widget _preferencesCard(BuildContext context) {
    return _card(
      icon: Icons.settings_outlined,
      title: 'Preferences',
      subtitle: 'Configure your timezone and locale settings.',
      children: [
        _fieldLabel('Timezone'),
        Obx(() => _dropdown(
              value: _presentValue(controller.selectedTimezone.value,
                  controller.timezones.map((e) => e.timeZone).toList()),
              items: controller.timezones
                  .map((e) => DropdownMenuItem<String>(
                        value: e.timeZone,
                        child: Text(e.display,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14)),
                      ))
                  .toList()
                ..addAll(_extraCurrentItem(
                    controller.selectedTimezone.value,
                    controller.timezones.map((e) => e.timeZone).toList())),
              hint: 'Select timezone',
              onChanged: (v) => controller.selectedTimezone.value = v ?? '',
            )),
        const SizedBox(height: 16),
        _fieldLabel('Language'),
        Obx(() => _dropdown(
              value: _presentValue(controller.selectedLanguage.value,
                  ProfileController.languageOptions),
              items: _withCurrent(ProfileController.languageOptions,
                  controller.selectedLanguage.value),
              hint: 'Select language',
              onChanged: (v) => controller.selectedLanguage.value = v ?? '',
            )),
        const SizedBox(height: 18),
        _workingHoursSection(context),
      ],
    );
  }

  Widget _workingHoursSection(BuildContext context) {
    return Obx(() {
      final expanded = controller.workingHoursExpanded.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tappable header with a rotating chevron — collapsed by default.
          InkWell(
            onTap: () => controller.workingHoursExpanded.toggle(),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Working Hours',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down,
                        color: _accent, size: 24),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: [
                const SizedBox(height: 6),
                ...ProfileController.dayKeys
                    .map((day) => _dayRow(context, day)),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _dayRow(BuildContext context, String day) {
    return Obx(() {
      final enabled = controller.isDayEnabled(day);
      final slots = controller.workingHours[day] ?? <WorkingHoursSlot>[];
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Transform.scale(
                  scale: 0.85,
                  child: Switch(
                    value: enabled,
                    activeColor: _accent,
                    onChanged: (v) => controller.toggleDay(day, v),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _capitalize(day),
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                ),
                if (enabled)
                  Text('${slots.length} slot${slots.length == 1 ? '' : 's'}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
            if (enabled) ...[
              const SizedBox(height: 4),
              ...List.generate(slots.length, (i) => _slotRow(context, day, i, slots[i])),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => controller.addSlot(day),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add slot'),
                  style: TextButton.styleFrom(
                    foregroundColor: _accent,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _slotRow(BuildContext context, String day, int index, WorkingHoursSlot slot) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: _timeBox(context, day, index, slot.from, isFrom: true)),
          const SizedBox(width: 8),
          Expanded(child: _timeBox(context, day, index, slot.to, isFrom: false)),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
            onPressed: () => controller.removeSlot(day, index),
          ),
        ],
      ),
    );
  }

  Widget _timeBox(BuildContext context, String day, int index, String value24,
      {required bool isFrom}) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: _parse24(value24),
        );
        if (picked != null) {
          final formatted = _format24(picked);
          controller.setSlotTime(day, index,
              from: isFrom ? formatted : null, to: isFrom ? null : formatted);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: Row(
          children: [
            Text(isFrom ? 'From ' : 'To ',
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            Expanded(
              child: Text(_display12(value24),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ),
            const Icon(Icons.access_time, size: 15, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Bottom bar
  // ===========================================================================
  Widget _bottomBar(bool saving) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: saving ? null : controller.resetForm,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reset'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  foregroundColor: Colors.black87,
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: saving ? null : controller.saveProfile,
                icon: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(saving ? 'Saving…' : 'Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F2937),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Small building blocks
  // ===========================================================================
  Widget _card({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(subtitle,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _fieldLabel(String label,
      {bool required = false, bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 2),
      child: Row(
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          if (required)
            const Text(' *', style: TextStyle(color: Colors.red, fontSize: 13)),
          if (readOnly)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F2F5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('Read only',
                  style: TextStyle(color: Colors.grey[600], fontSize: 10)),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _accent),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
    );
  }

  Widget _dropdown({
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required String hint,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      isExpanded: true,
      items: items,
      onChanged: onChanged,
      hint: Text(hint,
          style: const TextStyle(color: Colors.grey, fontSize: 14),
          overflow: TextOverflow.ellipsis),
      decoration: _inputDecoration(hint: hint),
      style: const TextStyle(fontSize: 14, color: Colors.black87),
    );
  }

  // Overload helper: builds DropdownMenuItems from plain strings.
  List<DropdownMenuItem<String>> _withCurrent(
      List<String> options, String current) {
    final all = <String>[...options];
    if (current.isNotEmpty && !all.contains(current)) {
      all.insert(0, current);
    }
    return all
        .map((o) => DropdownMenuItem<String>(
              value: o,
              child: Text(o,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14)),
            ))
        .toList();
  }

  // Extra item for a saved value that isn't in the fetched list (timezone).
  List<DropdownMenuItem<String>> _extraCurrentItem(
      String current, List<String> values) {
    if (current.isNotEmpty && !values.contains(current)) {
      return [
        DropdownMenuItem<String>(
          value: current,
          child: Text(current,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14)),
        )
      ];
    }
    return [];
  }

  // Returns the value only if it will exist among the dropdown items, else null
  // (prevents DropdownButton's "exactly one item" assertion).
  String? _presentValue(String value, List<String> values) {
    if (value.isEmpty) return null;
    return value; // _withCurrent / _extraCurrentItem guarantee it's present
  }

  // ===========================================================================
  // Formatting helpers
  // ===========================================================================
  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  TimeOfDay _parse24(String hhmm) {
    try {
      final p = hhmm.split(':');
      return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  String _format24(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _display12(String hhmm) {
    final t = _parse24(hhmm);
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '${h.toString().padLeft(2, '0')}:$m $period';
  }
}
