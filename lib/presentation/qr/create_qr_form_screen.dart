import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../core/error_messages.dart';
import '../../core/theme/app_colors.dart';
import '../../models/create_qr_draft.dart';
import '../widgets/ea_card.dart';
import '../widgets/ea_primary_button.dart';
import '../widgets/ea_text_field.dart';
import '../../data/api_client.dart';
import 'qr_flow_tab.dart';

const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'];

// Alphabetized union of 28 states and 8 union territories. Kept in one
// canonical list so the pincode-autofill result (which returns the
// state as India Post spells it) matches the dropdown option exactly.
const _indianStates = <String>[
  'Andaman and Nicobar Islands',
  'Andhra Pradesh',
  'Arunachal Pradesh',
  'Assam',
  'Bihar',
  'Chandigarh',
  'Chhattisgarh',
  'Dadra and Nagar Haveli and Daman and Diu',
  'Delhi',
  'Goa',
  'Gujarat',
  'Haryana',
  'Himachal Pradesh',
  'Jammu and Kashmir',
  'Jharkhand',
  'Karnataka',
  'Kerala',
  'Ladakh',
  'Lakshadweep',
  'Madhya Pradesh',
  'Maharashtra',
  'Manipur',
  'Meghalaya',
  'Mizoram',
  'Nagaland',
  'Odisha',
  'Puducherry',
  'Punjab',
  'Rajasthan',
  'Sikkim',
  'Tamil Nadu',
  'Telangana',
  'Tripura',
  'Uttar Pradesh',
  'Uttarakhand',
  'West Bengal',
];

// Hits India Post's public pincode API. Free, no auth, no rate limit
// concerns for our volume. Returns {state, city} on success, null on
// any failure (bad pincode, network error, weird response shape) — the
// UI just falls back to manual entry.
Future<({String state, String city})?> _lookupPincode(String pin) async {
  try {
    final uri = Uri.parse('https://api.postalpincode.in/pincode/$pin');
    final res = await http.get(uri).timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) return null;
    final decoded = jsonDecode(res.body);
    if (decoded is! List || decoded.isEmpty) return null;
    final first = decoded.first;
    if (first is! Map) return null;
    if (first['Status'] != 'Success') return null;
    final offices = first['PostOffice'];
    if (offices is! List || offices.isEmpty) return null;
    final po = offices.first;
    if (po is! Map) return null;
    final state = po['State']?.toString().trim() ?? '';
    // District is the closest thing to "city" India Post exposes.
    final city = (po['District'] ?? po['Block'] ?? po['Name'])?.toString().trim() ?? '';
    if (state.isEmpty || city.isEmpty) return null;
    return (state: state, city: city);
  } catch (_) {
    return null;
  }
}

// Forces every keystroke into uppercase — TextCapitalization.characters
// only sets the keyboard hint on Android, so lowercase can still slip in
// via paste or third-party keyboards.
class _UpperCaseFormatter extends TextInputFormatter {
  const _UpperCaseFormatter();
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

class CreateQrFormScreen extends StatefulWidget {
  const CreateQrFormScreen({
    super.key,
    required this.onBack,
    required this.onProceedToPayment,
    required this.onCreatedDirectly,
  });

  final VoidCallback onBack;
  final void Function(CreateQrDraft draft) onProceedToPayment;
  final void Function(QrCreateResult result) onCreatedDirectly;

  @override
  State<CreateQrFormScreen> createState() => _CreateQrFormScreenState();
}

class _CreateQrFormScreenState extends State<CreateQrFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _vehicle = TextEditingController();
  String _blood = 'Select blood group';

  // Shipping address for the physical sticker.
  final _addressLine1 = TextEditingController();
  final _addressLine2 = TextEditingController();
  final _city = TextEditingController();
  String? _state = 'Maharashtra'; // default; pincode autofill can override
  final _pincode = TextEditingController();
  // Track pincode-lookup lifecycle so the UI can show a spinner and so
  // we can ignore stale results (user typed 6 digits, then edited).
  bool _pincodeLoading = false;
  int _pincodeLookupToken = 0;
  Timer? _pincodeDebounce;

  // Four contact rows are always shown. Row 0 is mandatory; rows 1-3
  // are optional and skipped on submit if left blank. UI no longer
  // supports adding/removing rows — the count is fixed at 4.
  final List<_ContactRow> _contacts = List.generate(4, (_) => _ContactRow());
  // Non-blocking loading indicator for the submit button — form
  // validation + vehicle-check + navigation-to-payment all run through
  // this single flag so the button stays disabled with a spinner while
  // the network round-trip is in flight.
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _email.dispose();
    _vehicle.dispose();
    _addressLine1.dispose();
    _addressLine2.dispose();
    _city.dispose();
    _pincode.dispose();
    _pincodeDebounce?.cancel();
    for (final c in _contacts) {
      c.dispose();
    }
    super.dispose();
  }

  // Debounced pincode → state + city autofill. Fires the postal API
  // ~400ms after the user stops typing a 6-digit pincode. Uses a
  // monotonically-increasing token so a slow-arriving old response
  // can't overwrite a fresh new lookup.
  void _onPincodeChanged(String value) {
    _pincodeDebounce?.cancel();
    if (!RegExp(r'^[0-9]{6}$').hasMatch(value)) return;
    _pincodeDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      final myToken = ++_pincodeLookupToken;
      setState(() => _pincodeLoading = true);
      final result = await _lookupPincode(value);
      if (!mounted || myToken != _pincodeLookupToken) return;
      setState(() {
        _pincodeLoading = false;
        if (result != null) {
          // Only apply state if it's actually in our dropdown list —
          // guards against India Post returning a variant spelling.
          if (_indianStates.contains(result.state)) {
            _state = result.state;
          }
          // Fill city only if it's still empty; don't stomp on manual edits.
          if (_city.text.trim().isEmpty) {
            _city.text = result.city;
          }
        }
      });
    });
  }

  // Shared label styles. Card headers are prominent + centered; field
  // labels are bold and one size up from the input-theme default but
  // stay left-aligned above their inputs (easier to scan when the eye
  // is moving vertically down the form).
  TextStyle? _cardHeaderStyle(BuildContext c) => Theme.of(c)
      .textTheme
      .titleLarge
      ?.copyWith(
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      );

  TextStyle? _fieldLabelStyle(BuildContext c) => Theme.of(c)
      .textTheme
      .titleSmall
      ?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  Future<void> _submit() async {
    if (_submitting) return; // prevent double-tap
    if (!_formKey.currentState!.validate()) return;

    if (_blood == 'Select blood group') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select blood group')));
      return;
    }

    // Rows 1-3 are optional — a row with both name and phone blank is
    // dropped silently instead of failing validation, so the user can
    // register with just the mandatory Contact 1.
    final family = <FamilyContactDraft>[];
    for (var i = 0; i < _contacts.length; i++) {
      final c = _contacts[i];
      final n = c.name.text.trim();
      final p = c.phone.text.trim().replaceAll(RegExp(r'\s'), '');
      if (i > 0 && n.isEmpty && p.isEmpty) continue;
      family.add(FamilyContactDraft(name: n, phone: p));
    }

    final draft = CreateQrDraft(
      name: _name.text.trim(),
      mobile: _mobile.text.trim().replaceAll(RegExp(r'\s'), ''),
      email: _email.text.trim(),
      vehicleNumber: _vehicle.text.trim(),
      bloodGroup: _blood,
      family: family,
      shippingAddressLine1: _addressLine1.text.trim(),
      shippingAddressLine2: _addressLine2.text.trim(),
      shippingCity: _city.text.trim(),
      shippingState: (_state ?? '').trim(),
      shippingPincode: _pincode.text.trim(),
    );

    // Inline loading state — non-blocking; the button's own spinner
    // shows work is in progress without freezing the form under a
    // full-screen modal dialog.
    setState(() => _submitting = true);
    try {
      final checkVehicleNum = _vehicle.text.trim().toUpperCase();
      final checkRes =
          await ApiClient.instance.get('/qr/check-vehicle/$checkVehicleNum');
      if (!mounted) return;

      if (checkRes is Map && checkRes['exists'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This vehicle is already registered.'),
          ),
        );
        return;
      }

      // Vehicle is unique — hand the draft to the payment flow.
      widget.onProceedToPayment(draft);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ErrorMessages.friendly(e))));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
        title: const Text('Create Emergency QR'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    EaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Personal Information',
                            textAlign: TextAlign.center,
                            style: _cardHeaderStyle(context),
                          ),
                          const SizedBox(height: 14),
                          EaTextField(
                            controller: _name,
                            label: 'Full Name *',
                            hint: 'Enter your full name',
                            labelStyle: _fieldLabelStyle(context),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'This field is required' : null,
                          ),
                          const SizedBox(height: 14),
                          EaTextField(
                            controller: _mobile,
                            label: 'Mobile Number *',
                            hint: 'Enter 10-digit mobile number',
                            keyboardType: TextInputType.phone,
                            prefixIcon: Icons.phone_android_rounded,
                            maxLength: 10,
                            labelStyle: _fieldLabelStyle(context),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'This field is required';
                              if (!RegExp(r'^[0-9]{10}$').hasMatch(v.trim())) return 'Please enter a valid 10-digit mobile number';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          EaTextField(
                            controller: _email,
                            label: 'Email *',
                            hint: 'you@example.com',
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icons.email_outlined,
                            labelStyle: _fieldLabelStyle(context),
                            validator: (v) {
                              final s = (v ?? '').trim();
                              if (s.isEmpty) return 'This field is required';
                              if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s)) {
                                return 'Invalid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          EaTextField(
                            controller: _vehicle,
                            label: 'Vehicle Number *',
                            hint: 'MH31CR0289',
                            textCapitalization: TextCapitalization.characters,
                            labelStyle: _fieldLabelStyle(context),
                            inputFormatters: const [_UpperCaseFormatter()],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'This field is required';
                              if (!RegExp(r'^([A-Z]{2}[0-9]{2}[A-Z]{1,2}[0-9]{4}|[0-9]{2}BH[0-9]{4}[A-Z]{1,2})$').hasMatch(v.trim())) {
                                return 'Invalid Vehicle Number';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Blood Group *',
                            style: _fieldLabelStyle(context),
                          ),
                          const SizedBox(height: 8),
                          // Blood group values are 2–3 chars — a full-width
                          // dropdown looked comically empty and covered most
                          // of the screen when opened. Align + SizedBox
                          // breaks out of the card Column's stretch so the
                          // trigger (and the popup menu, which inherits the
                          // trigger's width) size to the content instead.
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: 220,
                              child: DropdownButtonFormField<String>(
                                // ignore: deprecated_member_use
                                value: _blood == 'Select blood group' ? null : _blood,
                                hint: const Text('Select blood group'),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: AppColors.inputFill,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                                items: _bloodGroups
                                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                                    .toList(),
                                onChanged: (v) => setState(() => _blood = v ?? _blood),
                                validator: (v) => v == null || v.isEmpty ? 'This field is required' : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    EaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Address',
                            textAlign: TextAlign.center,
                            style: _cardHeaderStyle(context),
                          ),
                          const SizedBox(height: 14),
                          EaTextField(
                            controller: _addressLine1,
                            label: 'Address Line 1 *',
                            hint: 'House/Flat number, Building, Street',
                            labelStyle: _fieldLabelStyle(context),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Address is required' : null,
                          ),
                          const SizedBox(height: 14),
                          EaTextField(
                            controller: _addressLine2,
                            label: 'Address Line 2',
                            hint: 'Landmark, Area (optional)',
                            labelStyle: _fieldLabelStyle(context),
                          ),
                          const SizedBox(height: 14),
                          // Pincode goes ABOVE city/state so the postal
                          // autofill can populate the next two fields as
                          // the user types. The suffix spinner tells the
                          // user why City/State briefly become read-only
                          // after they finish typing 6 digits.
                          EaTextField(
                            controller: _pincode,
                            label: 'Pincode *',
                            hint: '6-digit postal code',
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            labelStyle: _fieldLabelStyle(context),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: _onPincodeChanged,
                            suffix: _pincodeLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  )
                                : null,
                            validator: (v) {
                              final s = (v ?? '').trim();
                              if (s.isEmpty) return 'Pincode is required';
                              if (!RegExp(r'^[0-9]{6}$').hasMatch(s)) {
                                return 'Enter a valid 6-digit pincode';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: EaTextField(
                                  controller: _city,
                                  label: 'City *',
                                  hint: 'e.g., Pune',
                                  labelStyle: _fieldLabelStyle(context),
                                  validator: (v) => (v == null || v.trim().isEmpty)
                                      ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'State *',
                                      style: _fieldLabelStyle(context),
                                    ),
                                    const SizedBox(height: 8),
                                    DropdownButtonFormField<String>(
                                      // ignore: deprecated_member_use
                                      value: _state,
                                      isExpanded: true,
                                      hint: const Text('Select state',
                                          overflow: TextOverflow.ellipsis),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: AppColors.inputFill,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(14),
                                          borderSide: BorderSide.none,
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 14),
                                      ),
                                      items: _indianStates
                                          .map((s) => DropdownMenuItem(
                                                value: s,
                                                child: Text(
                                                  s,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ))
                                          .toList(),
                                      onChanged: (v) =>
                                          setState(() => _state = v),
                                      validator: (v) => (v == null || v.isEmpty)
                                          ? 'Required'
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    EaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Family Emergency Contacts',
                            textAlign: TextAlign.center,
                            style: _cardHeaderStyle(context),
                          ),
                          const SizedBox(height: 12),
                          ...List.generate(_contacts.length, (i) {
                            final c = _contacts[i];
                            final isRequired = i == 0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Contact ${i + 1}${isRequired ? '' : ' (optional)'}',
                                      textAlign: TextAlign.center,
                                      style: _cardHeaderStyle(context),
                                    ),
                                    const SizedBox(height: 10),
                                    EaTextField(
                                      controller: c.name,
                                      label: isRequired ? 'Name *' : 'Name',
                                      hint: 'Contact name',
                                      labelStyle: _fieldLabelStyle(context),
                                      validator: (v) {
                                        final s = (v ?? '').trim();
                                        if (isRequired && s.isEmpty) {
                                          return 'This field is required';
                                        }
                                        // Optional row: if name is filled but
                                        // phone is blank, block submit — half
                                        // a contact is useless.
                                        if (!isRequired &&
                                            s.isEmpty &&
                                            c.phone.text.trim().isNotEmpty) {
                                          return 'Name is required when phone is filled';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    EaTextField(
                                      controller: c.phone,
                                      label: isRequired
                                          ? 'Phone Number *'
                                          : 'Phone Number',
                                      hint: '10-digit number',
                                      keyboardType: TextInputType.phone,
                                      maxLength: 10,
                                      labelStyle: _fieldLabelStyle(context),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      validator: (v) {
                                        final s = (v ?? '').trim();
                                        if (isRequired && s.isEmpty) {
                                          return 'This field is required';
                                        }
                                        // Optional row: skip if fully blank,
                                        // otherwise enforce format.
                                        if (!isRequired && s.isEmpty) {
                                          if (c.name.text.trim().isNotEmpty) {
                                            return 'Phone is required when name is filled';
                                          }
                                          return null;
                                        }
                                        if (!RegExp(r'^[0-9]{10}$').hasMatch(s)) {
                                          return 'Please enter a valid 10-digit mobile number';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          Text(
                            '*Contact 1 is required. Contacts 2–4 are optional.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: EaPrimaryButton(
              label: _submitting ? 'Checking vehicle…' : 'Pay ₹549 & Create QR',
              icon: Icons.lock_rounded,
              loading: _submitting,
              onPressed: _submitting ? null : _submit,
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _ContactRow {
  _ContactRow() : name = TextEditingController(), phone = TextEditingController();

  final TextEditingController name;
  final TextEditingController phone;

  void dispose() {
    name.dispose();
    phone.dispose();
  }
}
