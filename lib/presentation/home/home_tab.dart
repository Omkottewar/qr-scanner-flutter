import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../widgets/glass_card.dart';
import '../widgets/notification_bell.dart';
import '../widgets/scale_tap.dart';
import 'widgets/home_carousel.dart';
import 'widgets/promo_video_card.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.onOpenQr});

  final VoidCallback onOpenQr;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const _AmbientBackground(),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 128),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(title: 'QR 4 Emergency'),
                  const SizedBox(height: 20),
                  const HomeCarousel(),
                  const SizedBox(height: 24),
                  _HeroCta(onCreate: onOpenQr),
                  const PromoVideoCard(),
                  const _SectionHeader(
                    title: 'Why QR 4 Emergency?',
                    subtitle: 'Built for moments that matter',
                  ),
                  const _Step(
                    n: '01',
                    color: Color(0xFFFF7A00),
                    icon: Icons.qr_code_2_rounded,
                    title: 'Generate your QR',
                    desc: 'Add up to 5 trusted emergency contacts in minutes.',
                  ),
                  const SizedBox(height: 12),
                  const _Step(
                    n: '02',
                    color: Color(0xFFFFB547),
                    icon: Icons.directions_car_rounded,
                    title: 'Stick it on your windshield',
                    desc: 'Weatherproof, scannable from any phone camera.',
                  ),
                  const SizedBox(height: 12),
                  const _Step(
                    n: '03',
                    color: Color(0xFF10B981),
                    icon: Icons.phone_callback_rounded,
                    title: 'Stay reachable, stay private',
                    desc: 'Numbers are masked — calls are bridged through QR 4 Emergency.',
                  ),
                  const _SectionHeader(
                    title: 'Key Features',
                    subtitle: 'Designed for real-world safety',
                  ),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    // 1.05 was clipping cards where the title wraps to
                    // two lines (Call/Spam Protection, Location Sharing).
                    // 0.88 gives each card enough vertical room for a
                    // 2-line title + 2-line description without cropping.
                    childAspectRatio: 0.88,
                    children: const [
                      _FeatureCard(
                        icon: Icons.qr_code_scanner_rounded,
                        color: Color(0xFFFF7A00),
                        title: 'QR Scanner',
                        desc: 'Scan with any smartphone camera.',
                      ),
                      _FeatureCard(
                        icon: Icons.bolt_rounded,
                        color: Color(0xFFFFB547),
                        title: 'Instant Connect',
                        desc: 'Connect to emergency contacts in one tap.',
                      ),
                      _FeatureCard(
                        icon: Icons.groups_rounded,
                        color: Color(0xFF3B82F6),
                        title: 'Trusted Contacts',
                        desc: 'Family, friends, caregivers, or anyone you trust.',
                      ),
                      _FeatureCard(
                        icon: Icons.smartphone_rounded,
                        color: Color(0xFF10B981),
                        title: 'Private Calling',
                        desc: 'Phone numbers stay hidden with secure call masking.',
                      ),
                      _FeatureCard(
                        icon: Icons.block_rounded,
                        color: Color(0xFFEF4444),
                        title: 'Call/Spam Protection',
                        desc: 'Prevents repeated unwanted calls and misuse.',
                      ),
                      _FeatureCard(
                        icon: Icons.location_on_rounded,
                        color: Color(0xFF06B6D4),
                        title: 'Location Sharing',
                        desc: "View the caller's live location when they choose to share it.",
                      ),
                    ],
                  ),
                  const _SectionHeader(
                    title: 'Subscription',
                    subtitle: 'One plan. Total peace of mind.',
                  ),
                  _SubscriptionCard(onSubscribe: onOpenQr),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(color: Color(0xFF06090F)),
          ),
          Positioned(
            top: -120,
            right: -120,
            child: _orb(const Color(0x47FF7A00), 320),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: _orb(const Color(0x408B5CF6), 320),
          ),
        ],
      ),
    );
  }

  Widget _orb(Color color, double size) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color, Colors.transparent], stops: const [0, 0.7]),
          ),
        ),
      );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.55),
                  blurRadius: 28,
                  spreadRadius: -6,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/logo.png',
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shield_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'BE NAYAK',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          _glassIcon(const NotificationBell(compact: true)),
        ],
      ),
    );
  }

  Widget _glassIcon(Widget child) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: child,
    );
  }
}

class _HeroCta extends StatelessWidget {
  const _HeroCta({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.6),
              blurRadius: 60,
              spreadRadius: -16,
              offset: const Offset(0, 28),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Decorative circle — behind the text, clipped to card shape
            // by the outer ClipRRect.
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // No `height` property — let the font's natural metrics
                  // reserve room for descenders. Wrap each line in its
                  // own Text so line 2 can't stomp on line 1's `y` tail.
                  const Text(
                    'Your family,',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const Text(
                    'one scan away.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                Text(
                  'One scan instantly connects to your emergency contacts.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                ScaleTap(
                  onTap: onCreate,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Create your QR',
                          style: TextStyle(
                            color: Color(0xFF7A3500),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded,
                            color: Color(0xFF7A3500), size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ), // Padding
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 36, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.n,
    required this.color,
    required this.icon,
    required this.title,
    required this.desc,
  });

  final String n;
  final Color color;
  final IconData icon;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.24)),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STEP $n',
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.24)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({required this.onSubscribe});
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -64,
              right: -64,
              child: Container(
                width: 192,
                height: 192,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'BASIC PLAN',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'QR 4 Emergency — Lifetime',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'BEST VALUE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ShaderMask(
                      shaderCallback: (b) =>
                          AppColors.brandGradient.createShader(b),
                      child: const Text(
                        '₹549',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.5,
                          height: 1,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text(
                        'one-time',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '₹499 platform fee + ₹50 shipping · No renewal charges ever',
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                ..._featureBullets,
                const SizedBox(height: 24),
                ScaleTap(
                  onTap: onSubscribe,
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.55),
                          blurRadius: 40,
                          spreadRadius: -10,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Get Started',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.shield_rounded,
                            color: Colors.white, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static const _features = <String>[
    'Up to 5 trusted emergency contacts',
    'Private calls with secure number masking',
    'Unlimited QR scans & emergency calls',
    'Spam call protection against repeated callers',
    'One-time payment · No annual renewal ever',
  ];

  List<Widget> get _featureBullets => _features
      .map(
        (f) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF10B981),
                  size: 12,
                  weight: 700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  f,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      )
      .toList();
}
