import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kReleaseMode;
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

// Slash-grouped so the picker shows 5 buttons instead of 9. Matches backend
// RELATIONS set in qr.service.js — legacy singular values were rewritten by
// migration 018.
const _relations = [
  'Father/Mother',
  'Sister/Brother',
  'Husband/Wife',
  'Son/Daughter',
  'Other',
];

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
  String? _state; // picked from _indianStates dropdown
  final _pincode = TextEditingController();
  // Track pincode-lookup lifecycle so the UI can show a spinner and so
  // we can ignore stale results (user typed 6 digits, then edited).
  bool _pincodeLoading = false;
  int _pincodeLookupToken = 0;
  Timer? _pincodeDebounce;

  final List<_ContactRow> _contacts = [_ContactRow()];
  // Default OFF everywhere so the primary flow — creating a QR through
  // real Razorpay test-mode checkout — is what fires when the user taps
  // the button. In debug the toggle is still visible so a developer can
  // opt back into the bypass path when needed (e.g., testing without a
  // network). In release the toggle is hidden entirely.
  bool _bypassPayment = false;

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

  void _addContact() {
    if (_contacts.length >= 5) return;
    setState(() => _contacts.add(_ContactRow()));
  }

  // Removes a contact row. If it's the last remaining one we don't drop
  // below 1 — instead we reset its fields so the form still submits with
  // the minimum required contact.
  void _removeContact(int index) {
    if (index < 0 || index >= _contacts.length) return;
    setState(() {
      if (_contacts.length == 1) {
        final only = _contacts[0];
        only.name.clear();
        only.phone.clear();
        only.relation = 'Father/Mother';
        return;
      }
      final row = _contacts.removeAt(index);
      row.dispose();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_blood == 'Select blood group') {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select blood group')));
      return;
    }

    final family = <FamilyContactDraft>[];
    for (var i = 0; i < _contacts.length; i++) {
      final c = _contacts[i];
      final n = c.name.text.trim();
      final p = c.phone.text.trim().replaceAll(RegExp(r'\s'), '');

      family.add(FamilyContactDraft(name: n, phone: p, relation: c.relation));
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

    // Verify vehicle existence first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );

    try {
      final checkVehicleNum = _vehicle.text.trim().toUpperCase();
      final checkRes = await ApiClient.instance.get('/qr/check-vehicle/$checkVehicleNum');
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loader

      if (checkRes is Map && checkRes['exists'] == true) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Validation Error', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
            content: const Text('Vehicle already exists in system.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
        );
        return;
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Dismiss loader
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorMessages.friendly(e))));
      return;
    }

    if (!_bypassPayment) {
      widget.onProceedToPayment(draft);
      return;
    }

    try {
      debugPrint('[qr/create] submitting draft');

      final body = {
        ...draft.toPaymentJson(),
        'razorpay_order_id': 'order_dev',
        'razorpay_payment_id':
            'pay_dev_${DateTime.now().millisecondsSinceEpoch}',
        'razorpay_signature': 'dev_sig',
      };

      final res = await ApiClient.instance.post('/qr/create', body);

      debugPrint('[qr/create] response: $res');

      if (!mounted) return;

      // Server contract: { unique_id, digits, alert_url, vehicle_number, ... }
      // Defensive against a shape drift — surface a clear error instead
      // of crashing on `null.toString()` in the mapping below.
      if (res is! Map) {
        throw Exception('Unexpected server response');
      }
      final uniqueId = res['unique_id']?.toString();
      final alertUrl = res['alert_url']?.toString();
      final vehicleNumber = res['vehicle_number']?.toString();
      if (uniqueId == null || alertUrl == null || vehicleNumber == null) {
        throw Exception('Server response missing required fields');
      }

      widget.onCreatedDirectly(
        QrCreateResult(
          uniqueId: uniqueId,
          digits: res['digits']?.toString() ?? '',
          alertUrl: alertUrl,
          vehicleNumber: vehicleNumber,
          ownerName: draft.name,
          bloodGroup: draft.bloodGroup,
          familyCount: draft.family.length,
        ),
      );
    } catch (e) {
      debugPrint('[qr/create] error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ErrorMessages.friendly(e))));
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Personal Information',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 14),
                          EaTextField(
                            controller: _name,
                            label: 'Full Name *',
                            hint: 'Enter your full name',
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
                            hint: 'e.g., MH12AB1234 or 22BH1234AA',
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: const [_UpperCaseFormatter()],
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'This field is required';
                              if (!RegExp(r'^([A-Z]{2}[0-9]{2}[A-Z]{1,2}[0-9]{4}|[0-9]{2}BH[0-9]{4}[A-Z]{1,2})$').hasMatch(v.trim())) {
                                return 'Invalid Vehicle Number';
                              }
                              return null;
                            },
                          ),
                          Text(
                            '*Format: standard Indian registration or BH-series (e.g., 22BH1234AA)',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 14),
                          Text('Blood Group *', style: Theme.of(context).inputDecorationTheme.labelStyle),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    EaCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shipping Address',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Where should we ship your printed QR sticker?',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 14),
                          EaTextField(
                            controller: _addressLine1,
                            label: 'Address Line 1 *',
                            hint: 'House/Flat number, Building, Street',
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Address is required' : null,
                          ),
                          const SizedBox(height: 14),
                          EaTextField(
                            controller: _addressLine2,
                            label: 'Address Line 2',
                            hint: 'Landmark, Area (optional)',
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
                                  validator: (v) => (v == null || v.trim().isEmpty)
                                      ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'State *',
                                      style: Theme.of(context).inputDecorationTheme.labelStyle,
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Family Emergency Contacts',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                              if (_contacts.length < 5)
                                OutlinedButton(
                                  onPressed: _addContact,
                                  child: const Text('+ Add'),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...List.generate(_contacts.length, (i) {
                            final c = _contacts[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text('Contact ${i + 1}', style: Theme.of(context).textTheme.labelLarge),
                                        ),
                                        // Remove-contact affordance. Always shown so a user who
                                        // accidentally tapped "+ Add" and has no data to fill can
                                        // back out. Kept enabled even when it's the only row —
                                        // instead of deleting the last row we clear it, so the
                                        // form still submits with 1 contact.
                                        IconButton(
                                          tooltip: 'Remove this contact',
                                          icon: const Icon(Icons.delete_outline_rounded,
                                              color: Colors.redAccent, size: 20),
                                          onPressed: () => _removeContact(i),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    EaTextField(
                                      controller: c.name,
                                      label: 'Name *',
                                      hint: 'Contact name',
                                      validator: (v) => (v == null || v.trim().isEmpty) ? 'This field is required' : null,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 5,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Relationship *',
                                                style: Theme.of(context).inputDecorationTheme.labelStyle,
                                              ),
                                              const SizedBox(height: 6),
                                              DropdownButtonFormField<String>(
                                                // ignore: deprecated_member_use
                                                value: c.relation,
                                                decoration: InputDecoration(
                                                  filled: true,
                                                  fillColor: AppColors.inputFill,
                                                  border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                    borderSide: BorderSide.none,
                                                  ),
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                                ),
                                                items: _relations
                                                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                                                    .toList(),
                                                onChanged: (v) => setState(() => c.relation = v ?? c.relation),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 5,
                                          child: EaTextField(
                                            controller: c.phone,
                                            label: 'Phone Number *',
                                            hint: '10-digit number',
                                            keyboardType: TextInputType.phone,
                                            maxLength: 10,
                                            inputFormatters: [
                                              FilteringTextInputFormatter.digitsOnly,
                                            ],
                                            validator: (v) {
                                              if (v == null || v.trim().isEmpty) return 'This field is required';
                                              if (!RegExp(r'^[0-9]{10}$').hasMatch(v.trim())) {
                                                return 'Please enter a valid 10-digit mobile number';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          Text(
                            '*You can add up to 5 emergency contacts',
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
          // Dev-only shortcut — never rendered in release builds.
          if (!kReleaseMode)
            SwitchListTile(
              title: const Text('Bypass Payment Gateway (debug only)'),
              subtitle: const Text('Off = real Razorpay test checkout · On = skip payment entirely'),
              value: _bypassPayment,
              onChanged: (val) => setState(() => _bypassPayment = val),
            ),
          // Test-mode reminder — only shown while we're on Razorpay test
          // keys, and only in debug builds. Give the tester the exact
          // card + CVV so they don't have to hunt through docs. Remove
          // this block (or gate on `rzp_live_` prefix) before shipping.
          if (!kReleaseMode && !_bypassPayment)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.science_outlined, color: AppColors.amber, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RAZORPAY TEST MODE',
                            style: TextStyle(
                              color: AppColors.amber,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Card: 4111 1111 1111 1111 · Expiry: any future date · CVV: any 3 digits · OTP: 1234',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: EaPrimaryButton(
              label: _bypassPayment ? 'Create QR Directly' : 'Pay ₹549 & Create QR',
              icon: _bypassPayment ? Icons.arrow_forward : Icons.lock_rounded,
              onPressed: _submit,
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _ContactRow {
  _ContactRow() : name = TextEditingController(), phone = TextEditingController(), relation = 'Father/Mother';

  final TextEditingController name;
  final TextEditingController phone;
  String relation;

  void dispose() {
    name.dispose();
    phone.dispose();
  }
}
