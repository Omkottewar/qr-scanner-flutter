import 'package:flutter/material.dart';

import 'widgets/qr_detail_card.dart';

class QrViewScreen extends StatelessWidget {
  const QrViewScreen({
    super.key,
    required this.alertUrl,
    required this.digits,
    required this.vehicleNumber,
    required this.ownerName,
    required this.bloodGroup,
    this.familyCount,
    this.isManual = false,
  });

  final String alertUrl;
  final String digits;
  final String vehicleNumber;
  final String ownerName;
  final String bloodGroup;
  final int? familyCount;
  final bool isManual;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your QR Code')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: QrDetailCard(
            alertUrl: alertUrl,
            digits: digits,
            vehicleNumber: vehicleNumber,
            ownerName: ownerName,
            bloodGroup: bloodGroup,
            familyCount: familyCount,
            isManual: isManual,
          ),
        ),
      ),
    );
  }
}
