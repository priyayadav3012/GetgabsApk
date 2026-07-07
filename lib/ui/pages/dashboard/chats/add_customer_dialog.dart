import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:getgabs/domain/controllers/dashboard/dashboard_controller.dart';
import 'package:getgabs/ui/themes/themes.dart';

class _CountryCodeOption {
  final String name;
  final String code;
  const _CountryCodeOption(this.name, this.code);
  String get label => '$name ($code)';
}

const List<_CountryCodeOption> _countryCodes = [
  _CountryCodeOption('India', '+91'),
  _CountryCodeOption('United States', '+1'),
  _CountryCodeOption('United Kingdom', '+44'),
  _CountryCodeOption('United Arab Emirates', '+971'),
  _CountryCodeOption('Australia', '+61'),
  _CountryCodeOption('Canada', '+1'),
  _CountryCodeOption('Singapore', '+65'),
];

void showAddCustomerDialog(DashboardController dashboardController) {
  Get.dialog(AddCustomerDialog(dashboardController: dashboardController));
}

class AddCustomerDialog extends StatefulWidget {
  final DashboardController dashboardController;
  const AddCustomerDialog({super.key, required this.dashboardController});

  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  _CountryCodeOption _selectedCountry = _countryCodes.first;
  int _nameLength = 0;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      setState(() => _nameLength = _nameController.text.length);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String hint) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: Colors.grey.shade300),
    );
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: Colors.grey.shade500),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: RichText(
          text: TextSpan(
            text: text,
            style: const TextStyle(
                color: Colors.black87, fontSize: 13, fontWeight: FontWeight.w600),
            children: const [
              TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Add New Chat',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  InkWell(
                    onTap: () => Get.back(),
                    child: const Icon(Icons.close, size: 20, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Start a new WhatsApp conversation with a customer.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 20),

              _label('Customer Name'),
              TextField(
                controller: _nameController,
                maxLength: 50,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z0-9\s\-']")),
                ],
                decoration: _fieldDecoration(
                        "Enter customer name (letters, numbers, spaces, -, ' only)")
                    .copyWith(counterText: ''),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('$_nameLength/50 characters',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              ),
              const SizedBox(height: 16),

              _label('Country Code'),
              DropdownButtonFormField<_CountryCodeOption>(
                initialValue: _selectedCountry,
                isExpanded: true,
                decoration: _fieldDecoration(''),
                items: _countryCodes
                    .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedCountry = value);
                },
              ),
              const SizedBox(height: 16),

              _label('WhatsApp Number'),
              TextField(
                controller: _numberController,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration:
                    _fieldDecoration('Enter phone number without country code'),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Get.back(),
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      foregroundColor: Colors.black87,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  Obx(() => ElevatedButton(
                        onPressed: widget.dashboardController.isAddingCustomer.value
                            ? null
                            : () async {
                                final success =
                                    await widget.dashboardController.addCustomer(
                                  customerName: _nameController.text,
                                  countryCode: _selectedCountry.code,
                                  whatsappNumber: _numberController.text,
                                );
                                if (success) Get.back();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.appThemeColor,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: widget.dashboardController.isAddingCustomer.value
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Add Customer',
                                style: TextStyle(color: Colors.white)),
                      )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
