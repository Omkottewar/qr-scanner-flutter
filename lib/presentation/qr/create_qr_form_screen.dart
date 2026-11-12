import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../core/error_messages.dart';
import '../../core/legal_content.dart';
import '../../core/theme/app_colors.dart';
import '../../data/api_client.dart';
import '../../models/create_qr_draft.dart';
import '../profile/legal_document_screen.dart';
import '../widgets/ea_primary_button.dart';
import '../widgets/ea_text_field.dart';
import '../widgets/qr_loader.dart';
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

// Display-only country list. Backend currently only accepts Indian
// orders — this dropdown exists for visual completeness and a future
// multi-country rollout. The user's selection is not sent to the server.
const _countries = <String>[
  'India',
  'United States',
  'United Kingdom',
  'Australia',
  'Canada',
  'Germany',
  'France',
  'Japan',
  'Singapore',
  'UAE',
  'Nepal',
  'Bangladesh',
  'Sri Lanka',
  'Malaysia',
  'Thailand',
  'New Zealand',
  'South Africa',
  'Saudi Arabia',
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
  DateTime? _dob;

  // Shipping address for the physical sticker.
  final _addressLine1 = TextEditingController();
  String _country = 'India'; // display-only, India preselected
  final _city = TextEditingController();
  String? _state = 'Maharashtra'; // default; pincode autofill can override
  final _pincode = TextEditingController();
  // Track pincode-lookup lifecycle so the UI can show a spinner and so
  // we can ignore stale results (user typed 6 digits, then edited).
  bool _pincodeLoading = false;
  int _pincodeLookupToken = 0;
  Timer? _pincodeDebounce;

  // Three contact rows are always shown. Row 0 is mandatory; rows 1-2
  // are optional and skipped on submit if left blank. UI no longer
  // supports adding/removing rows — the count is fixed at 3.
  final List<_ContactRow> _contacts = List.generate(3, (_) => _ContactRow());
  // Non-blocking loading indicator for the submit button — form
  // validation + vehicle-check + navigation-to-payment all run through
  // this single flag so the button stays disabled with a spinner while
  // the network round-trip is in flight.
  bool _submitting = false;

  // Must be ticked before submit is enabled. Mirrors the Privacy Policy +
  // Terms & Conditions acceptance capture expected by DPDP.
  bool _declarationAccepted = false;

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    _email.dispose();
    _vehicle.dispose();
    _addressLine1.dispose();
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
          if (_indianStates.contains(result.state)) {
            _state = result.state;
          }
          if (_city.text.trim().isEmpty) {
            _city.text = result.city;
          }
        }
      });
    });
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 25, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select date of birth',
    );
    if (picked != null && mounted) {
      setState(() => _dob = picked);
    }
  }

  void _openLegal(LegalDocument doc) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LegalDocumentScreen(document: doc)),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return; // prevent double-tap
    if (!_formKey.currentState!.validate()) return;

    if (_blood == 'Select blood group') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select blood group')),
      );
      return;
    }

    if (_dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your date of birth')),
      );
      return;
    }

    if (!_declarationAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please accept the Privacy Policy and Terms & Conditions to continue',
          ),
        ),
      );
      return;
    }

    // Every contact row is optional — any row with both name and phone
    // blank is dropped silently. A user can submit the form with zero
    // emergency contacts and the backend will accept that.
    final family = <FamilyContactDraft>[];
    for (final c in _contacts) {
      final n = c.name.text.trim();
      final p = c.phone.text.trim().replaceAll(RegExp(r'\s'), '');
      if (n.isEmpty && p.isEmpty) continue;
      family.add(FamilyContactDraft(name: n, phone: p));
    }

    final draft = CreateQrDraft(
      name: _name.text.trim(),
      dob: _dob,
      mobile: _mobile.text.trim().replaceAll(RegExp(r'\s'), ''),
      email: _email.text.trim(),
      vehicleNumber: _vehicle.text.trim(),
      bloodGroup: _blood,
      family: family,
      shippingAddressLine1: _addressLine1.text.trim(),
      shippingCity: _city.text.trim(),
      shippingState: (_state ?? '').trim(),
      shippingPincode: _pincode.text.trim(),
    );

    setState(() => _submitting = true);
    try {
      final checkVehicleNum = _vehicle.text.trim().toUpperCase();
      final checkRes = await ApiClient.instance.get('/qr/check-vehicle/$checkVehicleNum');
      if (!mounted) return;

      if (checkRes is Map && checkRes['exists'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This vehicle is already registered.')),
        );
        return;
      }

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Text('Create Emergency QR'),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Personal Information ─────────────────────────
                      const _SectionBanner(
                        icon: Icons.person_rounded,
                        title: 'Personal Information',
                      ),
                      const SizedBox(height: 14),
                      _FormCard(
                        children: [
                          // Full Name and DOB on their own full-width rows.
                          _FormField(
                            icon: Icons.person_outline_rounded,
                            label: 'Full Name',
                            child: EaTextField(
                              controller: _name,
                              hint: 'Enter your full name',
                              textCapitalization: TextCapitalization.words,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Required'
                                      : null,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _FormField(
                            icon: Icons.cake_outlined,
                            label: 'Date of Birth',
                            child: _DobInput(
                              value: _dob,
                              onTap: _pickDob,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _FormField(
                            icon: Icons.phone_android_rounded,
                            label: 'Mobile Number',
                            child: EaTextField(
                              controller: _mobile,
                              hint: '10-digit mobile number',
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Required';
                                }
                                if (!RegExp(r'^[0-9]{10}$').hasMatch(v.trim())) {
                                  return 'Please enter a valid 10-digit mobile number';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 18),
                          _FormField(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            child: EaTextField(
                              controller: _email,
                              hint: 'you@example.com',
                              keyboardType: TextInputType.emailAddress,
                              validator: (v) {
                                final s = (v ?? '').trim();
                                if (s.isEmpty) return 'Required';
                                if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                    .hasMatch(s)) {
                                  return 'Invalid email';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 18),
                          _FormField(
                            icon: Icons.directions_car_filled_outlined,
                            label: 'Vehicle Number',
                            child: EaTextField(
                              controller: _vehicle,
                              hint: 'MH12AB1234',
                              textCapitalization: TextCapitalization.characters,
                              inputFormatters: const [_UpperCaseFormatter()],
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Required';
                                }
                                if (!RegExp(
                                        r'^([A-Z]{2}[0-9]{2}[A-Z]{1,2}[0-9]{4}|[0-9]{2}BH[0-9]{4}[A-Z]{1,2})$')
                                    .hasMatch(v.trim())) {
                                  return 'Invalid Vehicle Number';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 18),
                          _FormField(
                            icon: Icons.bloodtype_outlined,
                            label: 'Blood Group',
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: 220,
                                child: DropdownButtonFormField<String>(
                                  // ignore: deprecated_member_use
                                  value: _blood == 'Select blood group'
                                      ? null
                                      : _blood,
                                  hint: const Text('Select blood group'),
                                  decoration: _dropdownDecoration(),
                                  items: _bloodGroups
                                      .map((b) => DropdownMenuItem(
                                            value: b,
                                            child: Text(b),
                                          ))
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _blood = v ?? _blood),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Required'
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Address ──────────────────────────────────────
                      const _SectionBanner(
                        icon: Icons.location_on_rounded,
                        title: 'Address',
                      ),
                      const SizedBox(height: 14),
                      // Fields flow from broadest geographic scope to most
                      // specific — Country → State → City → Pincode →
                      // Address — matching the way addresses are read on a
                      // shipping label. Pincode-triggered autofill still
                      // populates city/state when the user types pincode,
                      // which now simply overwrites any earlier entries if
                      // India Post has a different canonical spelling.
                      _FormCard(
                        children: [
                          _FormField(
                            icon: Icons.public_rounded,
                            label: 'Country',
                            child: DropdownButtonFormField<String>(
                              // ignore: deprecated_member_use
                              value: _country,
                              isExpanded: true,
                              decoration: _dropdownDecoration(),
                              items: _countries
                                  .map((c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(
                                          c,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _country = v ?? _country),
                            ),
                          ),
                          const SizedBox(height: 18),
                          _FormField(
                            icon: Icons.map_outlined,
                            label: 'State',
                            child: DropdownButtonFormField<String>(
                              // ignore: deprecated_member_use
                              value: _state,
                              isExpanded: true,
                              decoration: _dropdownDecoration(),
                              items: _indianStates
                                  .map((s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(
                                          s,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (v) => setState(() => _state = v),
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _FormField(
                            icon: Icons.location_city_outlined,
                            label: 'City',
                            child: EaTextField(
                              controller: _city,
                              hint: 'Your city',
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 18),
                          _FormField(
                            icon: Icons.pin_drop_outlined,
                            label: 'Pincode',
                            child: EaTextField(
                              controller: _pincode,
                              hint: '6-digit postal code',
                              keyboardType: TextInputType.number,
                              maxLength: 6,
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
                                        child: QrLoader(size: 20),
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
                          ),
                          const SizedBox(height: 18),
                          _FormField(
                            icon: Icons.home_outlined,
                            label: 'Address',
                            child: EaTextField(
                              controller: _addressLine1,
                              hint: 'House/Flat, Building, Street',
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Address is required'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Emergency Contacts ───────────────────────────
                      const _SectionBanner(
                        icon: Icons.groups_rounded,
                        title: 'Emergency Contacts',
                      ),
                      const SizedBox(height: 14),
                      // Every contact row is optional now — the user can
                      // submit the form with zero contacts filled in. The
                      // only rule left is "if you fill one half, fill the
                      // other half too" so we don't end up with orphan
                      // name/phone pairs.
                      ...List.generate(_contacts.length, (i) {
                        final c = _contacts[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _ContactCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _FormField(
                                  icon: Icons.person_outline_rounded,
                                  label: 'Name',
                                  child: EaTextField(
                                    controller: c.name,
                                    hint: 'Enter contact name',
                                    textCapitalization:
                                        TextCapitalization.words,
                                    validator: (v) {
                                      final s = (v ?? '').trim();
                                      if (s.isEmpty &&
                                          c.phone.text.trim().isNotEmpty) {
                                        return 'Name is required when phone is filled';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _FormField(
                                  icon: Icons.phone_android_rounded,
                                  label: 'Mobile Number',
                                  child: EaTextField(
                                    controller: c.phone,
                                    hint: '10-digit mobile number',
                                    keyboardType: TextInputType.phone,
                                    maxLength: 10,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    validator: (v) {
                                      final s = (v ?? '').trim();
                                      if (s.isEmpty) {
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
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 6),
                      _DeclarationCheckbox(
                        checked: _declarationAccepted,
                        onChanged: (v) =>
                            setState(() => _declarationAccepted = v),
                        onTapPrivacy: () =>
                            _openLegal(LegalContent.privacyPolicy),
                        onTapTerms: () =>
                            _openLegal(LegalContent.termsAndConditions),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: EaPrimaryButton(
                label: _submitting ? 'Checking vehicle…' : 'Pay ₹599 & Create QR',
                icon: Icons.lock_rounded,
                loading: _submitting,
                onPressed: (_submitting || !_declarationAccepted) ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration() => InputDecoration(
        filled: true,
        fillColor: AppColors.inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );
}

class _ContactRow {
  _ContactRow()
      : name = TextEditingController(),
        phone = TextEditingController();

  final TextEditingController name;
  final TextEditingController phone;

  void dispose() {
    name.dispose();
    phone.dispose();
  }
}

// -----------------------------------------------------------------------------
// Red section banner — the full-width rounded "QR 4 EMERGENCY"-style header
// that sits ABOVE the white content card. Icon on the left, a thin vertical
// divider, bold white title. Matches the reference UI.
// -----------------------------------------------------------------------------
class _SectionBanner extends StatelessWidget {
  const _SectionBanner({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFB71218), Color(0xFF8A0A10)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 18,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(width: 14),
          Container(
            width: 1.5,
            height: 26,
            color: Colors.white.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// White content card that sits below a `_SectionBanner`. Subtle hairline,
// soft lifted shadow, generous padding.
// -----------------------------------------------------------------------------
class _FormCard extends StatelessWidget {
  const _FormCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            spreadRadius: -6,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Form field wrapper — icon + bold label on top, input below. Mirrors the
// pattern in the reference UI (icon sits NEXT TO the label, NOT inside the
// input box). Any child widget can be the input (EaTextField, _DobInput,
// Dropdown — they all work here).
// -----------------------------------------------------------------------------
class _FormField extends StatelessWidget {
  const _FormField({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.textPrimary, size: 22),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Date-of-Birth tap-to-pick input. Renders ONLY the input box (no label) so
// it drops into a `_FormField` next to Full Name like any other text field.
// Tapping opens the native date picker.
// -----------------------------------------------------------------------------
class _DobInput extends StatelessWidget {
  const _DobInput({required this.value, required this.onTap});

  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final display = value == null
        ? ''
        : '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                display,
                style: TextStyle(
                  color: value == null
                      ? AppColors.textTertiary
                      : AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const Icon(
              Icons.calendar_today_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Contact card — plain white surface wrapping the name + phone fields. No
// numbered badge or required/optional chip: every contact is optional and
// the cards sit identically. The red "Emergency Contacts" section banner
// upstream is the only header the user needs.
// -----------------------------------------------------------------------------
class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 24,
            spreadRadius: -6,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

// -----------------------------------------------------------------------------
// Declaration checkbox with tappable Privacy Policy + Terms & Conditions
// links. Submit button stays disabled until this is ticked.
// -----------------------------------------------------------------------------
class _DeclarationCheckbox extends StatelessWidget {
  const _DeclarationCheckbox({
    required this.checked,
    required this.onChanged,
    required this.onTapPrivacy,
    required this.onTapTerms,
  });

  final bool checked;
  final ValueChanged<bool> onChanged;
  final VoidCallback onTapPrivacy;
  final VoidCallback onTapTerms;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: checked
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.hairline,
          width: checked ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: Checkbox(
              value: checked,
              onChanged: (v) => onChanged(v ?? false),
              activeColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                  children: [
                    const TextSpan(text: 'I have read and agree to the '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()..onTap = onTapPrivacy,
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Terms & Conditions',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()..onTap = onTapTerms,
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
