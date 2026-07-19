class FamilyContactDraft {
  FamilyContactDraft({this.name = '', this.phone = '', this.relation = 'Father'});

  String name;
  String phone;
  String relation;

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        'phone': phone.trim(),
        'relation': relation,
      };
}

class CreateQrDraft {
  CreateQrDraft({
    required this.name,
    required this.mobile,
    required this.email,
    required this.vehicleNumber,
    required this.bloodGroup,
    required this.family,
    required this.shippingAddressLine1,
    this.shippingAddressLine2 = '',
    required this.shippingCity,
    required this.shippingState,
    required this.shippingPincode,
  });

  final String name;
  final String mobile;
  final String email;
  final String vehicleNumber;
  final String bloodGroup;
  final List<FamilyContactDraft> family;

  // Shipping address for the physical sticker.
  final String shippingAddressLine1;
  final String shippingAddressLine2;
  final String shippingCity;
  final String shippingState;
  final String shippingPincode;

  Map<String, dynamic> toPaymentJson() => {
        'name': name.trim(),
        'mobile': mobile.trim(),
        'email': email.trim(),
        'vehicle_number': vehicleNumber.trim().toUpperCase(),
        'blood_group': bloodGroup,
        'family': family.map((e) => e.toJson()).toList(),
        'shipping_address_line1': shippingAddressLine1.trim(),
        'shipping_address_line2': shippingAddressLine2.trim(),
        'shipping_city': shippingCity.trim(),
        'shipping_state': shippingState.trim(),
        'shipping_pincode': shippingPincode.trim(),
      };
}
