import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../widgets/scale_tap.dart';
import 'widgets/home_carousel.dart';
import 'widgets/promo_ad_card.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.onOpenQr,
    required this.onOpenDrawer,
    this.updateAvailable = false,
    this.updateLatestVersion = '',
    this.updateMessage = '',
    this.updatePlayStoreUrl = '',
  });

  final VoidCallback onOpenQr;
  final VoidCallback onOpenDrawer;

  // Soft update signal, forwarded from MainShell → from main.dart's boot
  // version check. When true, we render a dismissible banner near the top
  // of home linking to Play Store.
  final bool updateAvailable;
  final String updateLatestVersion;
  final String updateMessage;
  final String updatePlayStoreUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F6),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _BrandHeader(onLogoTap: onOpenDrawer),
              if (updateAvailable)
                SliverToBoxAdapter(
                  child: _UpdateAvailableBanner(
                    latestVersion: updateLatestVersion,
                    message: updateMessage,
                    playStoreUrl: updatePlayStoreUrl,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              const SliverToBoxAdapter(child: _BannerCard()),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              const SliverToBoxAdapter(child: _FeaturesRail()),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverToBoxAdapter(child: _DealCard(onBuy: onOpenQr)),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              const SliverToBoxAdapter(child: _StepsSection()),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              SliverToBoxAdapter(child: _PricingSection(onSubscribe: onOpenQr)),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              const SliverToBoxAdapter(child: _TrustStrip()),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),
              const SliverToBoxAdapter(child: _CertificationsSection()),
              const SliverToBoxAdapter(child: SizedBox(height: 140)),
            ],
          ),
          // Floating promotional card — fetches the currently-active
          // creative from GET /api/app/promo-video. Admin uploads /
          // deletes via admin.html; users see it next time they open the
          // app. Draggable + dismissable; dismissals persist per URL.
          PromoAdCard(
            initialOffset: Offset(
              MediaQuery.of(context).size.width - 196,
              MediaQuery.of(context).size.height - 360,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Blue brand header — Flipkart-style colored strip at the top with the
// logo + wordmark + tagline. No search bar and no user-specific controls.
// -----------------------------------------------------------------------------
class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.onLogoTap});

  final VoidCallback onLogoTap;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      toolbarHeight: 68,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: false,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.brandGradient,
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                // Tapping the logo opens the side drawer — the hamburger
                // affordance for this app.
                GestureDetector(
                  onTap: onLogoTap,
                  behavior: HitTestBehavior.opaque,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/nayak.jpeg',
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.shield_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      // Tiny menu badge so the tap target reads as "open
                      // menu", not just "pretty logo".
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.menu_rounded,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'QR 4 Emergency',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          height: 1,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "India's trusted emergency QR network",
                        style: TextStyle(
                          color: Color(0xFFCFE0FF),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// -----------------------------------------------------------------------------
// Full-width banner card hosting the hero image carousel (rectangle aspect).
// -----------------------------------------------------------------------------
class _BannerCard extends StatelessWidget {
  const _BannerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: const HomeCarousel(),
    );
  }
}

// -----------------------------------------------------------------------------
// Flipkart-style "deal card" — gradient banner with the lifetime plan price
// prominently displayed. Diwali-tinted gradient for festive feel.
// -----------------------------------------------------------------------------
class _DealCard extends StatelessWidget {
  const _DealCard({required this.onBuy});
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: ScaleTap(
        onTap: onBuy,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFFE51E25), Color(0xFFB71218)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text(
                            'LIMITED OFFER',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Save ₹400',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'QR 4 Emergency Kit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: const [
                        Text(
                          '₹599',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            height: 1,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        SizedBox(width: 8),
                        Padding(
                          padding: EdgeInsets.only(bottom: 3),
                          child: Text(
                            '₹999',
                            style: TextStyle(
                              color: Color(0xFFFCDCDE),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: Color(0xFFFCDCDE),
                              height: 1,
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Padding(
                          padding: EdgeInsets.only(bottom: 3),
                          child: Text(
                            '40% off',
                            style: TextStyle(
                              color: Color(0xFFFFD966),
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'BUY NOW',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Horizontal product-style rail of feature cards — now second from the top,
// right under the hero carousel.
// -----------------------------------------------------------------------------
class _FeaturesRail extends StatelessWidget {
  const _FeaturesRail();

  static const _items = <_FeatureSpec>[
    _FeatureSpec(
      icon: Icons.qr_code_scanner_rounded,
      title: 'Universal QR Scanner',
      caption: 'Works on any smartphone camera',
      tag: 'POPULAR',
      color: Color(0xFFE51E25),
    ),
    _FeatureSpec(
      icon: Icons.bolt_rounded,
      title: 'Instant Connect',
      caption: 'Reach contacts in one tap',
      tag: 'TOP RATED',
      color: Color(0xFFFFB547),
    ),
    _FeatureSpec(
      icon: Icons.groups_rounded,
      title: 'Trusted Contacts',
      caption: 'Up to 3 family / friends',
      tag: null,
      color: Color(0xFF3B82F6),
    ),
    _FeatureSpec(
      icon: Icons.smartphone_rounded,
      title: 'Private Calling',
      caption: 'Numbers stay hidden',
      tag: 'PRIVATE',
      color: Color(0xFF10B981),
    ),
    _FeatureSpec(
      icon: Icons.block_rounded,
      title: 'Spam Protection',
      caption: 'Block repeat callers',
      tag: null,
      color: Color(0xFFEF4444),
    ),
    _FeatureSpec(
      icon: Icons.location_on_rounded,
      title: 'Location Sharing',
      caption: 'See caller location live',
      tag: null,
      color: Color(0xFF06B6D4),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'Top features'),
          const SizedBox(height: 12),
          SizedBox(
            height: 198,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) => _FeatureCard(
                spec: _items[i],
                phase: (i / _items.length),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureSpec {
  const _FeatureSpec({
    required this.icon,
    required this.title,
    required this.caption,
    required this.tag,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String caption;
  final String? tag;
  final Color color;
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.spec, required this.phase});
  final _FeatureSpec spec;
  // Fraction 0.0 .. 1.0 added to each card's animation clock so neighbour
  // cards don't pulse in lockstep — the rail feels like a wave of motion.
  final double phase;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0E3EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AnimatedFeatureIconBox(
            icon: spec.icon,
            color: spec.color,
            phase: phase,
          ),
          const SizedBox(height: 10),
          Text(
            spec.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF212121),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            spec.caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF878787),
              fontSize: 12,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          if (spec.tag != null)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF388E3C),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                spec.tag!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Animated icon box used inside each feature card. Picks a signature
// motion based on the icon so the rail feels alive:
//   • QR scanner  → a horizontal scan line sweeping top → bottom behind it
//   • Bolt        → pulsing glow halo + brief scale snap
//   • Smartphone  → gentle left-right wobble (ringing)
//   • Block       → slow continuous rotation
//   • Groups      → vertical bob
//   • Location    → radial pulse ring + scale breath
//
// Every variant also breathes (subtle scale 0.95 → 1.05) and gets a
// per-card `phase` offset so neighbouring cards aren't in lockstep.
// -----------------------------------------------------------------------------
class _AnimatedFeatureIconBox extends StatefulWidget {
  const _AnimatedFeatureIconBox({
    required this.icon,
    required this.color,
    required this.phase,
  });

  final IconData icon;
  final Color color;
  final double phase;

  @override
  State<_AnimatedFeatureIconBox> createState() =>
      _AnimatedFeatureIconBoxState();
}

class _AnimatedFeatureIconBoxState extends State<_AnimatedFeatureIconBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // Shifted animation value t ∈ [0, 1). Each card lives at its own point
  // in the cycle so the row animates like a wave rather than a strobe.
  double get _t => ((_c.value + widget.phase) % 1.0);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _t;
        // Sine wave 0 → 1 → 0 across the cycle — used for breathing.
        final breathe = (math.sin(t * math.pi * 2) * 0.5) + 0.5;

        final isBolt = widget.icon == Icons.bolt_rounded;
        final isScanner = widget.icon == Icons.qr_code_scanner_rounded;
        final isLocation = widget.icon == Icons.location_on_rounded;
        final isPhone = widget.icon == Icons.smartphone_rounded;
        final isBlock = widget.icon == Icons.block_rounded;
        // Groups and anything else → just the breathe.

        // Base breathing scale shared by every icon.
        double scale = 1.0 + breathe * 0.08;
        double rotation = 0;
        Offset translate = Offset.zero;

        // Bolt: quick flash scale snap when t is near 0.25 — like
        // electricity arcing.
        if (isBolt) {
          final flash = ((t - 0.25).abs() < 0.08)
              ? (1 - (t - 0.25).abs() / 0.08)
              : 0.0;
          scale = 1.0 + flash * 0.25;
        }
        // Smartphone: small ±8° rotation shake with phase.
        if (isPhone) {
          rotation = math.sin(t * math.pi * 8) * 0.14;
        }
        // Block: slow continuous rotation.
        if (isBlock) {
          rotation = t * math.pi * 2;
          scale = 1.0;
        }
        // Groups (fallback groups match 'none of the above' with just bob).
        if (widget.icon == Icons.groups_rounded) {
          translate = Offset(0, -breathe * 4);
        }
        // Location: subtle scale on top of ping ring below.
        if (isLocation) {
          scale = 1.0 + breathe * 0.1;
        }

        return Container(
          height: 86,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.08 + 0.06 * breathe),
            borderRadius: BorderRadius.circular(6),
          ),
          child: ClipRect(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Signature overlays BEHIND the icon.
                if (isScanner)
                  Positioned(
                    left: 10,
                    right: 10,
                    top: 8 + t * 60,
                    child: Container(
                      height: 2.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            widget.color.withValues(alpha: 0),
                            widget.color.withValues(alpha: 0.85),
                            widget.color.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (isLocation)
                  Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0),
                    child: Container(
                      width: 60 * t + 30,
                      height: 60 * t + 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.color.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                if (isBolt)
                  Container(
                    width: 50 + breathe * 10,
                    height: 50 + breathe * 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.color
                              .withValues(alpha: 0.25 + 0.35 * breathe),
                          blurRadius: 18 + 14 * breathe,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                  ),
                // The icon itself, with per-variant transform.
                Transform.translate(
                  offset: translate,
                  child: Transform.rotate(
                    angle: rotation,
                    child: Transform.scale(
                      scale: scale,
                      child: Icon(widget.icon, color: widget.color, size: 44),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Section title row — bold left title.
// -----------------------------------------------------------------------------
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF212121),
                fontSize: 17,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// How it works — three numbered steps on a white card.
// -----------------------------------------------------------------------------
class _StepsSection extends StatelessWidget {
  const _StepsSection();

  static const _steps = <_StepData>[
    _StepData(
      n: '1',
      title: 'Generate your QR',
      desc: 'Add up to 3 trusted emergency contacts.',
    ),
    _StepData(
      n: '2',
      title: 'Stick it on your windshield',
      desc: 'Weatherproof. Scannable from any phone camera.',
    ),
    _StepData(
      n: '3',
      title: 'Stay reachable, stay private',
      desc: 'Masked calls bridged through QR 4 Emergency.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'How it works'),
          const SizedBox(height: 12),
          for (final s in _steps) _StepRow(step: s),
        ],
      ),
    );
  }
}

class _StepData {
  const _StepData({required this.n, required this.title, required this.desc});
  final String n;
  final String title;
  final String desc;
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});
  final _StepData step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.12),
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Text(
              step.n,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: const TextStyle(
                    color: Color(0xFF212121),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.desc,
                  style: const TextStyle(
                    color: Color(0xFF878787),
                    fontSize: 13,
                    height: 1.4,
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

// -----------------------------------------------------------------------------
// Pricing section — Flipkart "product details" look.
// -----------------------------------------------------------------------------
class _PricingSection extends StatelessWidget {
  const _PricingSection({required this.onSubscribe});
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(title: 'Lifetime plan'),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.qr_code_2_rounded,
                    color: AppColors.primary,
                    size: 46,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'QR 4 Emergency Kit',
                        style: TextStyle(
                          color: Color(0xFF212121),
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: const [
                          Text(
                            '₹599',
                            style: TextStyle(
                              color: Color(0xFF212121),
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              height: 1,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          SizedBox(width: 8),
                          Padding(
                            padding: EdgeInsets.only(bottom: 3),
                            child: Text(
                              '₹999',
                              style: TextStyle(
                                color: Color(0xFF878787),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: Color(0xFF878787),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Padding(
                            padding: EdgeInsets.only(bottom: 3),
                            child: Text(
                              '40% off',
                              style: TextStyle(
                                color: Color(0xFF388E3C),
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ..._bullets,
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: _PulsingBuyButton(onTap: onSubscribe),
          ),
        ],
      ),
    );
  }

  static const _features = <String>[
    'Up to 3 trusted emergency contacts',
    'Private calls with secure number masking',
    'Unlimited QR scans & emergency calls',
    'Spam call protection against repeat callers',
    'One-time payment · No annual renewal ever',
  ];

  List<Widget> get _bullets => _features
      .map(
        (f) => Padding(
          padding: const EdgeInsets.fromLTRB(14, 5, 14, 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF388E3C),
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  f,
                  style: const TextStyle(
                    color: Color(0xFF212121),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      )
      .toList();
}

// -----------------------------------------------------------------------------
// Trust strip — 3 small cells (Secure / Private / Shipped).
// -----------------------------------------------------------------------------
class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      child: Row(
        children: const [
          Expanded(child: _TrustCell(
            icon: Icons.lock_rounded,
            label: 'Secure',
            caption: 'End-to-end',
          )),
          Expanded(child: _TrustCell(
            icon: Icons.verified_user_rounded,
            label: 'Private',
            caption: 'Masked calls',
          )),
          Expanded(child: _TrustCell(
            icon: Icons.local_shipping_rounded,
            label: 'Shipped',
            caption: 'Pan India',
          )),
        ],
      ),
    );
  }
}

class _TrustCell extends StatelessWidget {
  const _TrustCell({
    required this.icon,
    required this.label,
    required this.caption,
  });
  final IconData icon;
  final String label;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF212121),
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          caption,
          style: const TextStyle(
            color: Color(0xFF878787),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Certifications section — styled like a "Claim your benefits" banner
// panel. Brand-red gradient background hosts an eyebrow label, a bold
// headline, and a 2-column grid of white benefit-style cards. Each card
// gets a circular gradient icon badge, a title, a muted scope summary
// and a "View certificate →" CTA at the bottom.
//
// Backed by CP Infotech & CP Network Pvt. Ltd.'s actual registrations:
// ISO 9001:2015, ISO/IEC 27001:2022, and MSME Udyam.
// -----------------------------------------------------------------------------
class _CertificationsSection extends StatelessWidget {
  const _CertificationsSection();

  static const _certs = <_CertSpec>[
    _CertSpec(
      icon: Icons.workspace_premium_rounded,
      title: 'ISO 9001:2015',
      subtitle: 'Quality Management System',
      number: 'ICIL-CPNPL-26-0510544',
      color: Color(0xFFE51E25),
    ),
    _CertSpec(
      icon: Icons.security_rounded,
      title: 'ISO/IEC 27001:2022',
      subtitle: 'Information Security Management',
      number: 'ICIL-CPNPL-26-0510545',
      color: Color(0xFF059669),
    ),
    _CertSpec(
      icon: Icons.verified_rounded,
      title: 'Udyam MSME',
      subtitle: 'Govt. of India Registration',
      number: 'UDYAM-MH-20-0373862',
      color: Color(0xFFB45309),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7A2127), Color(0xFF4E1518)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Verified',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'INDEPENDENT CERTIFICATIONS',
                style: TextStyle(
                  color: Color(0xFFF1C9CB),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'CP Infotech & CP Network Pvt. Ltd. product, audited '
                'under ISO and MSME frameworks.',
                style: TextStyle(
                  color: Color(0xFFE6C6C9),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              // 2-per-row grid. Third card sits alone in the second
              // row, left-aligned — matches the Airtel reference layout.
              _CertGrid(certs: _certs),
            ],
          ),
        ),
      ),
    );
  }
}

class _CertSpec {
  const _CertSpec({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.number,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final String number;
  final Color color;
}

// 2-column grid built with Rows (not GridView) so the cards don't need a
// fixed height and expand to fit their own content. Odd final cards sit
// alone on the last row, left-aligned.
class _CertGrid extends StatelessWidget {
  const _CertGrid({required this.certs});
  final List<_CertSpec> certs;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (int i = 0; i < certs.length; i += 2) {
      final left = certs[i];
      final right = i + 1 < certs.length ? certs[i + 1] : null;
      rows.add(
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _CertCard(spec: left)),
                const SizedBox(width: 12),
                Expanded(
                  child: right != null
                      ? _CertCard(spec: right)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _CertCard extends StatelessWidget {
  const _CertCard({required this.spec});
  final _CertSpec spec;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  spec.color.withValues(alpha: 0.95),
                  spec.color.withValues(alpha: 0.75),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: spec.color.withValues(alpha: 0.35),
                  blurRadius: 14,
                  spreadRadius: -2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(spec.icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 14),
          Text(
            spec.title,
            style: const TextStyle(
              color: Color(0xFF151515),
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            spec.subtitle,
            style: const TextStyle(
              color: Color(0xFF6B6B6B),
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          // Two lines so long cert IDs (ICIL-CPNPL-26-0510544) don't
          // get ellipsized at the narrow 2-up grid width.
          Text(
            spec.number,
            maxLines: 2,
            overflow: TextOverflow.visible,
            softWrap: true,
            style: const TextStyle(
              color: Color(0xFF9AA0A6),
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()],
              letterSpacing: 0.2,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'VIEW CERTIFICATE',
                style: TextStyle(
                  color: spec.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_rounded,
                color: spec.color,
                size: 14,
              ),
            ],
          ),
        ],
      ),
    );
  }
}



// -----------------------------------------------------------------------------
// Pulsing BUY NOW button — gentle breathing glow around the pill. Hooks the
// user's eye to the primary conversion action in the pricing section.
// -----------------------------------------------------------------------------
class _PulsingBuyButton extends StatefulWidget {
  const _PulsingBuyButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_PulsingBuyButton> createState() => _PulsingBuyButtonState();
}

class _PulsingBuyButtonState extends State<_PulsingBuyButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        return ScaleTap(
          onTap: widget.onTap,
          child: Container(
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35 + 0.3 * t),
                  blurRadius: 14 + 10 * t,
                  spreadRadius: -2,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Transform.scale(
              scale: 1 + 0.02 * t,
              child: const Text(
                'BUY NOW',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}


// -----------------------------------------------------------------------------
// Soft update-available banner — fires when the backend's /version-check
// says a newer version is on Play Store but this build is still within
// the supported window. Dismissals persist per-version in SharedPreferences
// so the next release re-raises the banner even if the user had hidden
// the previous one.
// -----------------------------------------------------------------------------
class _UpdateAvailableBanner extends StatefulWidget {
  const _UpdateAvailableBanner({
    required this.latestVersion,
    required this.message,
    required this.playStoreUrl,
  });

  final String latestVersion;
  final String message;
  final String playStoreUrl;

  @override
  State<_UpdateAvailableBanner> createState() => _UpdateAvailableBannerState();
}

class _UpdateAvailableBannerState extends State<_UpdateAvailableBanner> {
  static const String _kDismissPrefKey = 'update_banner_dismissed_version';
  bool _ready = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _loadDismissalState();
  }

  Future<void> _loadDismissalState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissedFor = prefs.getString(_kDismissPrefKey) ?? '';
      final hide = dismissedFor.isNotEmpty &&
          dismissedFor == widget.latestVersion;
      if (!mounted) return;
      setState(() {
        _dismissed = hide;
        _ready = true;
      });
    } catch (_) {
      if (!mounted) return;
      // On read failure, show the banner — better one extra prompt than
      // silently swallowing an update signal.
      setState(() => _ready = true);
    }
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDismissPrefKey, widget.latestVersion);
    } catch (_) {
      // Dismissal didn't persist — the banner will reappear on next
      // boot, which is fine.
    }
  }

  Future<void> _openStore() async {
    final url = widget.playStoreUrl.trim();
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Fallback: in-app browser if the external launcher refused.
      try {
        await launchUrl(uri);
      } catch (_) {/* give up silently */}
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _dismissed) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 18,
              spreadRadius: -4,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.system_update_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Update available',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.1,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.message.isEmpty
                        ? 'A new version is on Play Store.'
                        : widget.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFFFE2CC),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ScaleTap(
              onTap: _openStore,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'UPDATE',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismiss,
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
