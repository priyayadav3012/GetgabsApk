import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:getgabs/domain/controllers/dashboard/dashboard_controller.dart';
import 'package:getgabs/ui/themes/themes.dart';

class _CountryCodeOption {
  final String name;
  final String code;
  const _CountryCodeOption(this.name, this.code);
}

// National significant number length (digits after the country code) for
// commonly-used countries. Countries not listed fall back to a permissive
// generic max (see _numberMaxLengthFor) rather than guessing incorrectly.
const Map<String, int> _countryNumberLength = {
  'India': 10,
  'United States': 10,
  'Canada': 10,
  'United Kingdom': 10,
  'United Arab Emirates': 9,
  'Saudi Arabia': 9,
  'Australia': 9,
  'Singapore': 8,
  'Pakistan': 10,
  'Bangladesh': 10,
  'China': 11,
  'France': 9,
  'Germany': 11,
  'Nigeria': 10,
  'South Africa': 9,
  'Brazil': 11,
  'Russia': 10,
  'Japan': 10,
  'Indonesia': 12,
  'Malaysia': 10,
  'Philippines': 10,
  'Vietnam': 10,
  'Egypt': 10,
  'Kenya': 9,
  'Mexico': 10,
  'Italy': 10,
  'Spain': 9,
  'Netherlands': 9,
  'Sri Lanka': 9,
  'Nepal': 10,
};

int _numberMaxLengthFor(_CountryCodeOption country) =>
    _countryNumberLength[country.name] ?? 12;

/// For countries with a known national number length, the number must be
/// exactly that long — fewer digits (e.g. "98765" for a 10-digit India
/// number) is not a valid number and must not be submitted. Countries not
/// in the map only get the permissive max-length check above, since their
/// exact length isn't known.
bool _isValidNumberLength(_CountryCodeOption country, int enteredLength) {
  final exactLength = _countryNumberLength[country.name];
  if (exactLength == null) return enteredLength > 0;
  return enteredLength == exactLength;
}

const List<_CountryCodeOption> _countryCodes = [
  _CountryCodeOption('Afghanistan', '+93'),
  _CountryCodeOption('Albania', '+355'),
  _CountryCodeOption('Algeria', '+213'),
  _CountryCodeOption('Andorra', '+376'),
  _CountryCodeOption('Angola', '+244'),
  _CountryCodeOption('Antigua and Barbuda', '+1268'),
  _CountryCodeOption('Argentina', '+54'),
  _CountryCodeOption('Armenia', '+374'),
  _CountryCodeOption('Australia', '+61'),
  _CountryCodeOption('Austria', '+43'),
  _CountryCodeOption('Azerbaijan', '+994'),
  _CountryCodeOption('Bahamas', '+1242'),
  _CountryCodeOption('Bahrain', '+973'),
  _CountryCodeOption('Bangladesh', '+880'),
  _CountryCodeOption('Barbados', '+1246'),
  _CountryCodeOption('Belarus', '+375'),
  _CountryCodeOption('Belgium', '+32'),
  _CountryCodeOption('Belize', '+501'),
  _CountryCodeOption('Benin', '+229'),
  _CountryCodeOption('Bhutan', '+975'),
  _CountryCodeOption('Bolivia', '+591'),
  _CountryCodeOption('Bosnia and Herzegovina', '+387'),
  _CountryCodeOption('Botswana', '+267'),
  _CountryCodeOption('Brazil', '+55'),
  _CountryCodeOption('Brunei', '+673'),
  _CountryCodeOption('Bulgaria', '+359'),
  _CountryCodeOption('Burkina Faso', '+226'),
  _CountryCodeOption('Burundi', '+257'),
  _CountryCodeOption('Cambodia', '+855'),
  _CountryCodeOption('Cameroon', '+237'),
  _CountryCodeOption('Canada', '+1'),
  _CountryCodeOption('Cape Verde', '+238'),
  _CountryCodeOption('Central African Republic', '+236'),
  _CountryCodeOption('Chad', '+235'),
  _CountryCodeOption('Chile', '+56'),
  _CountryCodeOption('China', '+86'),
  _CountryCodeOption('Colombia', '+57'),
  _CountryCodeOption('Comoros', '+269'),
  _CountryCodeOption('Congo (DRC)', '+243'),
  _CountryCodeOption('Congo (Republic)', '+242'),
  _CountryCodeOption('Costa Rica', '+506'),
  _CountryCodeOption('Croatia', '+385'),
  _CountryCodeOption('Cuba', '+53'),
  _CountryCodeOption('Cyprus', '+357'),
  _CountryCodeOption('Czech Republic', '+420'),
  _CountryCodeOption('Denmark', '+45'),
  _CountryCodeOption('Djibouti', '+253'),
  _CountryCodeOption('Dominica', '+1767'),
  _CountryCodeOption('Dominican Republic', '+1809'),
  _CountryCodeOption('Ecuador', '+593'),
  _CountryCodeOption('Egypt', '+20'),
  _CountryCodeOption('El Salvador', '+503'),
  _CountryCodeOption('Equatorial Guinea', '+240'),
  _CountryCodeOption('Eritrea', '+291'),
  _CountryCodeOption('Estonia', '+372'),
  _CountryCodeOption('Eswatini', '+268'),
  _CountryCodeOption('Ethiopia', '+251'),
  _CountryCodeOption('Fiji', '+679'),
  _CountryCodeOption('Finland', '+358'),
  _CountryCodeOption('France', '+33'),
  _CountryCodeOption('Gabon', '+241'),
  _CountryCodeOption('Gambia', '+220'),
  _CountryCodeOption('Georgia', '+995'),
  _CountryCodeOption('Germany', '+49'),
  _CountryCodeOption('Ghana', '+233'),
  _CountryCodeOption('Greece', '+30'),
  _CountryCodeOption('Grenada', '+1473'),
  _CountryCodeOption('Guatemala', '+502'),
  _CountryCodeOption('Guinea', '+224'),
  _CountryCodeOption('Guinea-Bissau', '+245'),
  _CountryCodeOption('Guyana', '+592'),
  _CountryCodeOption('Haiti', '+509'),
  _CountryCodeOption('Honduras', '+504'),
  _CountryCodeOption('Hungary', '+36'),
  _CountryCodeOption('Iceland', '+354'),
  _CountryCodeOption('India', '+91'),
  _CountryCodeOption('Indonesia', '+62'),
  _CountryCodeOption('Iran', '+98'),
  _CountryCodeOption('Iraq', '+964'),
  _CountryCodeOption('Ireland', '+353'),
  _CountryCodeOption('Israel', '+972'),
  _CountryCodeOption('Italy', '+39'),
  _CountryCodeOption('Ivory Coast', '+225'),
  _CountryCodeOption('Jamaica', '+1876'),
  _CountryCodeOption('Japan', '+81'),
  _CountryCodeOption('Jordan', '+962'),
  _CountryCodeOption('Kazakhstan', '+7'),
  _CountryCodeOption('Kenya', '+254'),
  _CountryCodeOption('Kiribati', '+686'),
  _CountryCodeOption('Kosovo', '+383'),
  _CountryCodeOption('Kuwait', '+965'),
  _CountryCodeOption('Kyrgyzstan', '+996'),
  _CountryCodeOption('Laos', '+856'),
  _CountryCodeOption('Latvia', '+371'),
  _CountryCodeOption('Lebanon', '+961'),
  _CountryCodeOption('Lesotho', '+266'),
  _CountryCodeOption('Liberia', '+231'),
  _CountryCodeOption('Libya', '+218'),
  _CountryCodeOption('Liechtenstein', '+423'),
  _CountryCodeOption('Lithuania', '+370'),
  _CountryCodeOption('Luxembourg', '+352'),
  _CountryCodeOption('Madagascar', '+261'),
  _CountryCodeOption('Malawi', '+265'),
  _CountryCodeOption('Malaysia', '+60'),
  _CountryCodeOption('Maldives', '+960'),
  _CountryCodeOption('Mali', '+223'),
  _CountryCodeOption('Malta', '+356'),
  _CountryCodeOption('Marshall Islands', '+692'),
  _CountryCodeOption('Mauritania', '+222'),
  _CountryCodeOption('Mauritius', '+230'),
  _CountryCodeOption('Mexico', '+52'),
  _CountryCodeOption('Micronesia', '+691'),
  _CountryCodeOption('Moldova', '+373'),
  _CountryCodeOption('Monaco', '+377'),
  _CountryCodeOption('Mongolia', '+976'),
  _CountryCodeOption('Montenegro', '+382'),
  _CountryCodeOption('Morocco', '+212'),
  _CountryCodeOption('Mozambique', '+258'),
  _CountryCodeOption('Myanmar', '+95'),
  _CountryCodeOption('Namibia', '+264'),
  _CountryCodeOption('Nauru', '+674'),
  _CountryCodeOption('Nepal', '+977'),
  _CountryCodeOption('Netherlands', '+31'),
  _CountryCodeOption('New Zealand', '+64'),
  _CountryCodeOption('Nicaragua', '+505'),
  _CountryCodeOption('Niger', '+227'),
  _CountryCodeOption('Nigeria', '+234'),
  _CountryCodeOption('North Korea', '+850'),
  _CountryCodeOption('North Macedonia', '+389'),
  _CountryCodeOption('Norway', '+47'),
  _CountryCodeOption('Oman', '+968'),
  _CountryCodeOption('Pakistan', '+92'),
  _CountryCodeOption('Palau', '+680'),
  _CountryCodeOption('Palestine', '+970'),
  _CountryCodeOption('Panama', '+507'),
  _CountryCodeOption('Papua New Guinea', '+675'),
  _CountryCodeOption('Paraguay', '+595'),
  _CountryCodeOption('Peru', '+51'),
  _CountryCodeOption('Philippines', '+63'),
  _CountryCodeOption('Poland', '+48'),
  _CountryCodeOption('Portugal', '+351'),
  _CountryCodeOption('Qatar', '+974'),
  _CountryCodeOption('Romania', '+40'),
  _CountryCodeOption('Russia', '+7'),
  _CountryCodeOption('Rwanda', '+250'),
  _CountryCodeOption('Saint Kitts and Nevis', '+1869'),
  _CountryCodeOption('Saint Lucia', '+1758'),
  _CountryCodeOption('Saint Vincent and the Grenadines', '+1784'),
  _CountryCodeOption('Samoa', '+685'),
  _CountryCodeOption('San Marino', '+378'),
  _CountryCodeOption('Sao Tome and Principe', '+239'),
  _CountryCodeOption('Saudi Arabia', '+966'),
  _CountryCodeOption('Senegal', '+221'),
  _CountryCodeOption('Serbia', '+381'),
  _CountryCodeOption('Seychelles', '+248'),
  _CountryCodeOption('Sierra Leone', '+232'),
  _CountryCodeOption('Singapore', '+65'),
  _CountryCodeOption('Slovakia', '+421'),
  _CountryCodeOption('Slovenia', '+386'),
  _CountryCodeOption('Solomon Islands', '+677'),
  _CountryCodeOption('Somalia', '+252'),
  _CountryCodeOption('South Africa', '+27'),
  _CountryCodeOption('South Korea', '+82'),
  _CountryCodeOption('South Sudan', '+211'),
  _CountryCodeOption('Spain', '+34'),
  _CountryCodeOption('Sri Lanka', '+94'),
  _CountryCodeOption('Sudan', '+249'),
  _CountryCodeOption('Suriname', '+597'),
  _CountryCodeOption('Sweden', '+46'),
  _CountryCodeOption('Switzerland', '+41'),
  _CountryCodeOption('Syria', '+963'),
  _CountryCodeOption('Taiwan', '+886'),
  _CountryCodeOption('Tajikistan', '+992'),
  _CountryCodeOption('Tanzania', '+255'),
  _CountryCodeOption('Thailand', '+66'),
  _CountryCodeOption('Timor-Leste', '+670'),
  _CountryCodeOption('Togo', '+228'),
  _CountryCodeOption('Tonga', '+676'),
  _CountryCodeOption('Trinidad and Tobago', '+1868'),
  _CountryCodeOption('Tunisia', '+216'),
  _CountryCodeOption('Turkey', '+90'),
  _CountryCodeOption('Turkmenistan', '+993'),
  _CountryCodeOption('Tuvalu', '+688'),
  _CountryCodeOption('Uganda', '+256'),
  _CountryCodeOption('Ukraine', '+380'),
  _CountryCodeOption('United Arab Emirates', '+971'),
  _CountryCodeOption('United Kingdom', '+44'),
  _CountryCodeOption('United States', '+1'),
  _CountryCodeOption('Uruguay', '+598'),
  _CountryCodeOption('Uzbekistan', '+998'),
  _CountryCodeOption('Vanuatu', '+678'),
  _CountryCodeOption('Vatican City', '+379'),
  _CountryCodeOption('Venezuela', '+58'),
  _CountryCodeOption('Vietnam', '+84'),
  _CountryCodeOption('Yemen', '+967'),
  _CountryCodeOption('Zambia', '+260'),
  _CountryCodeOption('Zimbabwe', '+263'),
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
  _CountryCodeOption _selectedCountry =
      _countryCodes.firstWhere((c) => c.name == 'India');
  int _nameLength = 0;

  final GlobalKey _countryFieldKey = GlobalKey();
  bool _isCountryDropdownOpen = false;
  // While the country picker's search field is focused, its keyboard would
  // otherwise make the enclosing Dialog shift (Dialog auto-avoids the
  // keyboard via MediaQuery.viewInsets), sliding the Country Code field out
  // from under the already-positioned popup. Freezing the insets the Dialog
  // sees for the popup's duration keeps the field — and the popup — still.
  EdgeInsets? _frozenViewInsets;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      setState(() => _nameLength = _nameController.text.length);
    });
    _numberController.addListener(() => setState(() {}));
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

  Future<void> _openCountryDropdown() async {
    // Move the dialog to the top first so there's maximum room below the
    // field for the list (and the keyboard the search box may later open),
    // then wait for that layout change to settle before measuring anything.
    setState(() => _isCountryDropdownOpen = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final renderBox =
        _countryFieldKey.currentContext!.findRenderObject() as RenderBox;
    final overlayBox =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final fieldSize = renderBox.size;
    final fieldTopLeft =
        renderBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final fieldBottomRight = renderBox.localToGlobal(
      fieldSize.bottomRight(Offset.zero),
      ancestor: overlayBox,
    );

    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    // The panel's height is fixed once shown, but the user can still tap
    // the search field later and open the keyboard — reserve space for
    // that now so the popup doesn't end up half-covered when they do.
    final keyboardHeight =
        [mediaQuery.viewInsets.bottom, screenHeight * 0.35].reduce(
      (a, b) => a > b ? a : b,
    );

    const margin = 8.0;
    const minPanelHeight = 220.0;
    const maxPanelHeight = 420.0;

    final spaceBelow = screenHeight -
        keyboardHeight -
        mediaQuery.padding.bottom -
        (fieldTopLeft.dy + fieldSize.height) -
        margin;
    final panelHeight = spaceBelow < minPanelHeight
        ? minPanelHeight
        : (spaceBelow > maxPanelHeight ? maxPanelHeight : spaceBelow);

    setState(() => _frozenViewInsets = mediaQuery.viewInsets);

    final result = await showMenu<_CountryCodeOption>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(fieldTopLeft, fieldBottomRight),
        Offset.zero & overlayBox.size,
      ),
      constraints: BoxConstraints(
        minWidth: fieldSize.width,
        maxWidth: fieldSize.width,
      ),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      items: [
        PopupMenuItem<_CountryCodeOption>(
          enabled: false,
          padding: EdgeInsets.zero,
          height: panelHeight,
          child: _CountryDropdownPanel(
            selected: _selectedCountry,
            maxHeight: panelHeight,
            onSelected: (c) => Navigator.of(context).pop(c),
          ),
        ),
      ],
    );

    if (!mounted) return;
    setState(() {
      _isCountryDropdownOpen = false;
      _frozenViewInsets = null;
      if (result != null) {
        _selectedCountry = result;
        final maxLength = _numberMaxLengthFor(result);
        if (_numberController.text.length > maxLength) {
          _numberController.text =
              _numberController.text.substring(0, maxLength);
        }
      }
    });
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
    final dialog = Dialog(
      backgroundColor: Colors.white,
      alignment:
          _isCountryDropdownOpen ? Alignment.topCenter : Alignment.center,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: _isCountryDropdownOpen ? 40 : 24,
        bottom: 24,
      ),
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
              InkWell(
                key: _countryFieldKey,
                borderRadius: BorderRadius.circular(8),
                onTap: _isCountryDropdownOpen ? null : _openCountryDropdown,
                child: InputDecorator(
                  decoration: _fieldDecoration(''),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${_selectedCountry.name} (${_selectedCountry.code})',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                              fontWeight: FontWeight.w500, fontSize: 14),
                        ),
                      ),
                      Icon(
                        _isCountryDropdownOpen
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.grey.shade600,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _label('WhatsApp Number'),
              TextField(
                controller: _numberController,
                keyboardType: TextInputType.phone,
                maxLength: _numberMaxLengthFor(_selectedCountry),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _fieldDecoration(
                        'Enter phone number without country code')
                    .copyWith(counterText: ''),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_numberController.text.length}/${_numberMaxLengthFor(_selectedCountry)} digits',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                ),
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
                                if (!_isValidNumberLength(_selectedCountry,
                                    _numberController.text.length)) {
                                  EasyLoading.showError(
                                    '${_selectedCountry.name} numbers must be exactly ${_numberMaxLengthFor(_selectedCountry)} digits',
                                    duration: const Duration(seconds: 5),
                                  );
                                  return;
                                }
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

    if (_frozenViewInsets == null) return dialog;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(viewInsets: _frozenViewInsets),
      child: dialog,
    );
  }
}

class _CountryDropdownPanel extends StatefulWidget {
  final _CountryCodeOption selected;
  final double maxHeight;
  final ValueChanged<_CountryCodeOption> onSelected;
  const _CountryDropdownPanel({
    required this.selected,
    required this.maxHeight,
    required this.onSelected,
  });

  @override
  State<_CountryDropdownPanel> createState() => _CountryDropdownPanelState();
}

class _CountryDropdownPanelState extends State<_CountryDropdownPanel> {
  final _searchController = TextEditingController();
  final _listScrollController = ScrollController();
  late List<_CountryCodeOption> _filtered = _countryCodes;

  @override
  void dispose() {
    _searchController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _countryCodes
          : _countryCodes
              .where((c) =>
                  c.name.toLowerCase().contains(q) || c.code.contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.maxHeight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search country...',
                hintStyle:
                    TextStyle(color: Colors.grey.shade500, fontSize: 13),
                prefixIcon:
                    Icon(Icons.search, size: 20, color: Colors.grey.shade600),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade500),
                ),
              ),
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No matching country'),
                  )
                : Scrollbar(
                    controller: _listScrollController,
                    thumbVisibility: true,
                    child: ListView.builder(
                      controller: _listScrollController,
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final c = _filtered[index];
                          final isSelected = c.name == widget.selected.name &&
                              c.code == widget.selected.code;
                          return InkWell(
                            onTap: () => widget.onSelected(c),
                            child: Container(
                              color: isSelected ? Colors.grey.shade100 : null,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${c.name} (${c.code})',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                      style: TextStyle(
                                        color: isSelected
                                            ? AppTheme.appThemeColor
                                            : Colors.black87,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(Icons.check,
                                        size: 18,
                                        color: AppTheme.appThemeColor),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}
