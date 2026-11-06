class FamilyContactDraft {
  FamilyContactDraft({this.name = '', this.phone = ''});

  String name;
  String phone;

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'phone': phone.trim(),
      };
}

class CreateQrDraft {
  CreateQrDraft({
    required this.name,
    this.dob,
    required this.mobile,
    required this.email,
    required this.vehicleNumber,
    required this.bloodGroup,
    required this.family,
    required this.shippingAddressLine1,
    required this.shippingCity,
    required this.shippingState,
    required this.shippingPincode,
  });

  final String name;
  // Date of birth captured on the form. Nullable because old drafts
  // persisted before the field existed still deserialize cleanly.
  final DateTime? dob;
  final String mobile;
  final String email;
  final String vehicleNumber;
  final String bloodGroup;
  final List<FamilyContactDraft> family;

  // Shipping address for the physical sticker.
  final String shippingAddressLine1;
  final String shippingCity;
  final String shippingState;
  final String shippingPincode;

  Map<String, dynamic> toPaymentJson() => {
        'name': name.trim(),
        if (dob != null) 'dob': _formatDob(dob!),
        'mobile': mobile.trim(),
        'email': email.trim(),
        'vehicle_number': vehicleNumber.trim().toUpperCase(),
        'blood_group': bloodGroup,
        'family': family.map((e) => e.toJson()).toList(),
        'shipping_address_line1': shippingAddressLine1.trim(),
        'shipping_city': shippingCity.trim(),
        'shipping_state': shippingState.trim(),
        'shipping_pincode': shippingPincode.trim(),
      };
}

// ISO-8601 date-only (yyyy-mm-dd). Backend can parse this cleanly into
// a Postgres DATE column without timezone drift.
String _formatDob(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
