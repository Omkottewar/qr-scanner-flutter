import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../widgets/ea_card.dart';
import '../widgets/ea_primary_button.dart';
import 'qr_flow_tab.dart';
import 'widgets/qr_detail_card.dart';

class QrSuccessScreen extends StatefulWidget {
  const QrSuccessScreen({super.key, required this.result, required this.onGoHome});

  final QrCreateResult result;
  final VoidCallback onGoHome;

  @override
  State<QrSuccessScreen> createState() => _QrSuccessScreenState();
}

class _QrSuccessScreenState extends State<QrSuccessScreen> {
  QrCreateResult get result => widget.result;

  @override
  void initState() {
    super.initState();
    // Show the delivery timing dialog once, after the first frame so the
    // Scaffold is mounted. Users who navigate away and come back don't
    // see it again — this screen only ever renders once per flow.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_shipping_rounded,
                color: AppColors.primary, size: 30),
          ),
          title: const Text('Your QR is on the way!', textAlign: TextAlign.center),
          content: const Text(
            'Your QR sticker will be delivered to your door in 3–5 working days.',
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got it', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Ready')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              QrDetailCard(
                alertUrl: result.alertUrl,
                digits: result.digits,
                vehicleNumber: result.vehicleNumber,
                ownerName: result.ownerName,
                bloodGroup: result.bloodGroup,
                familyCount: result.familyCount,
              ),
              const SizedBox(height: 8),
              Text(
                'QR ID: ${result.uniqueId}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                    ),
              ),
              const SizedBox(height: 16),
              EaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next Steps',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    _NextStep(
                      n: '1',
                      color: const Color(0xFFFFE4E4),
                      title: 'Download the QR Code',
                      subtitle: 'Save the QR code image to your device.',
                    ),
                    _NextStep(
                      n: '2',
                      color: const Color(0xFFFFF3E0),
                      title: 'Print the QR Sticker',
                      subtitle: 'Waterproof stickers ship within 3–5 days.',
                    ),
                    _NextStep(
                      n: '3',
                      color: const Color(0xFFE8F5E9),
                      title: 'Place on Vehicle',
                      subtitle: 'Stick on the windshield where it is visible.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              EaPrimaryButton(
                label: 'Go to Home',
                icon: Icons.home_outlined,
                onPressed: widget.onGoHome,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextStep extends StatelessWidget {
  const _NextStep({
    required this.n,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final String n;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color,
            child: Text(n, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
