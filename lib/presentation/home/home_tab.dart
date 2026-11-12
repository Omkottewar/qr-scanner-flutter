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
              SliverToBoxAdapter(
                child: _CertificationsSection(onTapScan: onOpenQr),
              ),
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
      width: 170,
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
            // Two lines so "Universal QR Scanner" and other longer titles
            // wrap gracefully instead of ellipsizing mid-word. Short
            // titles (e.g. "Instant Connect") still render on one line
            // because Column sizes to content.
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF212121),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.2,
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
// Certifications section — "credentials vault" module. Light outer wrapper
// (matches the home-page card rhythm) holds a dark-maroon inner carousel
// of gold medallions. Each slide shows 4 circular credentials with a
// center "BE NAYAK / TAP TO SCAN" button that opens the scanner tab.
//
// Data-driven: dump every registration into `_allCerts` and the carousel
// auto-chunks them 4-per-slide with dots at the bottom. Only the real,
// verifiable credentials belong in that list — fake ones would mislead
// customers and expose the company to consumer-protection complaints.
// -----------------------------------------------------------------------------
class _CertificationsSection extends StatefulWidget {
  const _CertificationsSection({required this.onTapScan});

  final VoidCallback onTapScan;

  // Every entry in this list becomes one gold medallion. New entries are
  // automatically paginated 4 per slide — no layout changes needed when
  // you add the remaining registrations. Order inside the list is the
  // visual order (slide 1 top-left → slide 1 top-right → slide 1
  // bottom-left → slide 1 bottom-right → slide 2 …).
  //
  // Field guide:
  //   category — eyebrow above the medallion ("QUALITY SYSTEM")
  //   title    — cert headline ("ISO 9001")
  //   subtitle — year / issuer line ("2015 CERTIFIED")
  //   chip     — short promise shown in the pill below ("Quality Assured")
  //   icon     — material symbol that reads as the cert's domain
  //   accent   — medium-bright color used for the icon + chip tint; the
  //              gold ring around each medallion is shared so brand feel
  //              stays consistent across slides
  static const _allCerts = <_CertSpec>[
    // ── Slide 1 ──────────────────────────────────────────────────────────
    _CertSpec(
      category: 'QUALITY SYSTEM',
      title: 'ISO 9001',
      subtitle: '2015 CERTIFIED',
      chip: 'Quality Assured',
      icon: Icons.workspace_premium_rounded,
      accent: Color(0xFFFFC85A),
      fullTitle: 'ISO 9001:2015 Quality Management System',
      summary:
          'Independent audit confirming the Quality Management System meets the international ISO 9001:2015 standard.',
      legalEntity: 'C P NETWORK PRIVATE LIMITED',
      registrationNumber: 'ICIL-CPNPL-26-0510544',
      issuedBy: 'International Certification Inspection Limited (UK)',
      issuedOn: '05-10-2026',
      validUntil: '04-10-2029',
      scope:
          'Provision of broadcasting, import and export services, and internet-based services including VoIP, broadband, wireless data, online services, marketing, print and digital media.',
    ),
    _CertSpec(
      category: 'INFO SECURITY',
      title: 'ISO 27001',
      subtitle: '2022 CERTIFIED',
      chip: 'Data Protected',
      icon: Icons.verified_user_rounded,
      accent: Color(0xFF4CD2A0),
      fullTitle: 'ISO/IEC 27001:2022 Information Security Management',
      summary:
          'International benchmark certifying an audited information security management system covering the entire business.',
      legalEntity: 'C P NETWORK PRIVATE LIMITED',
      registrationNumber: 'ICIL-CPNPL-26-0510545',
      issuedBy: 'International Certification Inspection Limited (UK)',
      issuedOn: '05-10-2026',
      validUntil: '04-10-2029',
      scope:
          'Provision of broadcasting, import and export services, and internet-based services including VoIP, broadband, wireless data, online services, marketing, print and digital media.',
    ),
    _CertSpec(
      category: 'GOVT. REGISTERED',
      title: 'UDYAM MSME',
      subtitle: 'GOVT. OF INDIA',
      chip: 'Micro Enterprise',
      icon: Icons.account_balance_rounded,
      accent: Color(0xFFFFB547),
      fullTitle: 'Udyam MSME Registration',
      summary:
          'Government of India Ministry of MSME registration recognising the enterprise as a Micro Small and Medium Enterprise.',
      legalEntity: 'C P INFOTECH',
      registrationNumber: 'UDYAM-MH-20-0293149',
      issuedBy:
          'Ministry of Micro, Small and Medium Enterprises, Govt. of India',
      issuedOn: '07-10-2025',
      scope:
          'Manufacturing · Electric power generation using solar energy (NIC 35105). Classified as a Micro Enterprise.',
    ),
    _CertSpec(
      category: 'GLOBAL CREDIBILITY',
      title: 'D-U-N-S',
      subtitle: 'D&B REGISTERED',
      chip: 'Verified Brand',
      icon: Icons.auto_awesome_rounded,
      accent: Color(0xFF6B9FF0),
      fullTitle: 'D&B D-U-N-S® Number',
      summary:
          'Dun & Bradstreet unique nine-digit identifier used worldwide by businesses, governments, and procurement systems to verify the entity.',
      legalEntity: 'C.P. NETWORK PRIVATE LIMITED',
      registrationNumber: '860284292',
      issuedBy: 'Dun & Bradstreet',
      scope:
          'Global business identity verification. Required for Startup India D-U-N-S Trust, Apple Developer registration, international procurement, and export documentation.',
    ),

    // ── Slide 2 ──────────────────────────────────────────────────────────
    _CertSpec(
      category: 'TAX COMPLIANT',
      title: 'GST',
      subtitle: 'REG-06 CERTIFIED',
      chip: 'GST Registered',
      icon: Icons.receipt_long_rounded,
      accent: Color(0xFFFFA07A),
      fullTitle: 'Goods and Services Tax (GST) Registration',
      summary:
          'Government of India Form GST REG-06 certificate. Every invoice and purchase from the business is fully tax-compliant.',
      legalEntity: 'C P INFOTECH',
      registrationNumber: '27IEIPP7022D2ZD',
      issuedBy: 'Government of India · Goods and Services Tax',
      issuedOn: '21-10-2026',
      scope: 'Regular GST registration for the proprietorship.',
    ),
    _CertSpec(
      category: 'EXPORT & IMPORT',
      title: 'IEC',
      subtitle: 'DGFT CERTIFIED',
      chip: 'Global Trade',
      icon: Icons.public_rounded,
      accent: Color(0xFF7BC6FF),
      fullTitle: 'Importer-Exporter Code (IEC)',
      summary:
          'DGFT-issued code required for international trade. Lets the business legally import and export goods and services across borders.',
      legalEntity: 'C P INFOTECH',
      registrationNumber: 'IEIPP7022D',
      issuedBy:
          'Directorate General of Foreign Trade, Ministry of Commerce and Industry',
      issuedOn: '04-11-2026',
      scope: 'Cross-border import and export of goods and services.',
    ),
    _CertSpec(
      category: 'FINANCE',
      title: 'TReDS',
      subtitle: 'RXIL SELLER',
      chip: 'Credit Enabled',
      icon: Icons.trending_up_rounded,
      accent: Color(0xFF9ECB6B),
      fullTitle: 'RXIL TReDS Exchange Registration',
      summary:
          'Registered as a Seller on the Receivables Exchange of India (RXIL), the RBI-regulated TReDS platform for financing trade receivables.',
      legalEntity: 'C P INFOTECH',
      registrationNumber: 'CP0167850',
      issuedBy:
          'Receivables Exchange of India Limited (RXIL — NSE × SIDBI JV)',
      issuedOn: '09-11-2026',
      scope:
          'Discounting trade receivables with multiple financiers on the RBI-regulated TReDS platform.',
    ),
    _CertSpec(
      category: 'GOVT. MARKETPLACE',
      title: 'GeM',
      subtitle: 'VERIFIED SELLER',
      chip: 'GeM Seller',
      icon: Icons.storefront_rounded,
      accent: Color(0xFFFFBFD4),
      fullTitle: 'Government e-Marketplace (GeM) Seller',
      summary:
          'Registered Seller on the Government e-Marketplace — the official procurement portal used by every Indian central and state government body.',
      legalEntity: 'C P INFOTECH',
      registrationNumber: 'GD1W260015006576',
      issuedBy: 'Government e-Marketplace (GeM), Govt. of India',
      issuedOn: '11-10-2022',
      scope:
          'Supplier of IT services, software, hardware, and allied products to Indian government buyers via the GeM portal.',
    ),

    // ── Slide 3 ──────────────────────────────────────────────────────────
    _CertSpec(
      category: 'TRADEMARK',
      title: 'TM CLASS 9',
      subtitle: 'SOFTWARE & TECH',
      chip: 'Brand Protected',
      icon: Icons.copyright_rounded,
      accent: Color(0xFFD6A0FF),
      fullTitle: 'Trademark — Class 9 (Computers, Software, Security Devices)',
      summary:
          'Trademark application covering the C.P. INFOTECH mark across software, AI/ML, cryptography, computer hardware, and safety & signalling devices.',
      legalEntity: 'C P INFOTECH',
      registrationNumber: 'Temp. Ref. 15498930',
      issuedBy: 'Trade Marks Registry, Govt. of India',
      issuedOn: '04-11-2026',
      scope:
          'Software, AI/ML, utility/security/cryptography software, peripherals, computers, image-capture equipment, safety & signalling devices.',
    ),
    _CertSpec(
      category: 'TRADEMARK',
      title: 'TM CLASS 35',
      subtitle: 'RETAIL & ADS',
      chip: 'Brand Protected',
      icon: Icons.copyright_rounded,
      accent: Color(0xFFFF9FD6),
      fullTitle: 'Trademark — Class 35 (Advertising, Marketing, Retail)',
      summary:
          'Trademark application covering advertising, marketing, retail, e-commerce, digital marketing, and consumer information services.',
      legalEntity: 'C P INFOTECH',
      registrationNumber: 'Temp. Ref. 15500205',
      issuedBy: 'Trade Marks Registry, Govt. of India',
      issuedOn: '04-11-2026',
      scope:
          'Advertising, marketing, commercial trading, retail & wholesale, e-commerce, digital marketing, food products, agro products, appliances, electrical goods and accessories.',
    ),
    _CertSpec(
      category: 'TRADEMARK',
      title: 'TM CLASS 42',
      subtitle: 'IT SERVICES',
      chip: 'Brand Protected',
      icon: Icons.copyright_rounded,
      accent: Color(0xFFB9A9FF),
      fullTitle: 'Trademark — Class 42 (IT, Software, Design Services)',
      summary:
          'Trademark application covering IT services, software development, hosting, SaaS, IT consultancy, IT security, data services, and design.',
      legalEntity: 'C P INFOTECH',
      registrationNumber: 'Temp. Ref. 15500251',
      issuedBy: 'Trade Marks Registry, Govt. of India',
      issuedOn: '04-11-2026',
      scope:
          'IT services, software development, programming, hosting, SaaS, software rental, IT consultancy, IT security, data duplication/conversion, data coding, design services.',
    ),
    _CertSpec(
      category: 'FOOD SAFETY',
      title: 'FSSAI',
      subtitle: 'FSS ACT 2006',
      chip: 'Food Grade',
      icon: Icons.restaurant_rounded,
      accent: Color(0xFFFF8C7A),
      fullTitle: 'FSSAI Food Safety Registration',
      summary:
          'Food Safety and Standards Authority of India registration — mandatory for any business that handles, stores, or sells food products.',
      legalEntity: 'C P INFOTECH',
      registrationNumber: '21526077003044',
      issuedBy:
          'Food Safety and Standards Authority of India (FDA Maharashtra)',
      issuedOn: '02-11-2026',
      validUntil: '01-11-2031',
      scope:
          'Retailer for fats & oils, ready-to-eat savouries, prepared foods, nutritional foods, Indian sweets & savouries, salts/spices/sauces, confectionery, cereals, and bakery products.',
    ),

    // ── Slide 4 ──────────────────────────────────────────────────────────
    _CertSpec(
      category: 'SKILL INDIA',
      title: 'SKILL INDIA',
      subtitle: 'MIN. OF SKILL DEV.',
      chip: 'Skill Verified',
      icon: Icons.school_rounded,
      accent: Color(0xFFFFE28A),
      fullTitle: 'Skill India — eKYC Verified Profile',
      summary:
          'eKYC-verified profile on the Government of India Skill India portal under the Ministry of Skill Development and Entrepreneurship.',
      legalEntity: 'C P INFOTECH',
      issuedBy:
          'Ministry of Skill Development and Entrepreneurship, Govt. of India',
      scope:
          'Aadhaar-linked skills and digital CV registered on the National Skill India platform.',
    ),
    _CertSpec(
      category: 'CAREER NETWORK',
      title: 'NCS',
      subtitle: 'GOVT. OF INDIA',
      chip: 'Employer Verified',
      icon: Icons.work_rounded,
      accent: Color(0xFFFFB55A),
      fullTitle: 'National Career Service — Verified Employer',
      summary:
          'Registered Employer on the Government of India National Career Service portal. Lets the company post jobs and connect with jobseekers.',
      legalEntity: 'C P INFOTECH',
      issuedBy: 'Ministry of Labour & Employment, Govt. of India',
      scope:
          'Employer profile with Director verified identity; permitted to post jobs and search jobseekers.',
    ),
    _CertSpec(
      category: 'ESTABLISHMENT',
      title: 'SHOPS ACT',
      subtitle: 'MAHARASHTRA',
      chip: 'Licensed',
      icon: Icons.store_rounded,
      accent: Color(0xFF8BE0C0),
      fullTitle: 'Maharashtra Shops & Establishment Registration',
      summary:
          'Maharashtra Shops and Establishments (Regulation of Employment and Conditions of Service) Act, 2017 — mandatory registration for every commercial establishment in the state.',
      legalEntity: 'C P INFOTECH',
      registrationNumber: '255523003208484894',
      issuedBy:
          'Additional Commissioner of Labour, Nagpur · Govt. of Maharashtra',
      issuedOn: '07-10-2025',
      scope:
          'Commercial establishment registered under the Maharashtra Shops & Establishments Act. Nature: Solar services.',
    ),
    _CertSpec(
      category: 'PAYMENT PARTNER',
      title: 'RAZORPAY',
      subtitle: 'PCI-DSS LEVEL 1',
      chip: 'Secure Payments',
      icon: Icons.account_balance_wallet_rounded,
      accent: Color(0xFF53A7FF),
      fullTitle: 'Razorpay — Payment Gateway Partner',
      summary:
          "Every in-app purchase is processed through Razorpay — India's PCI-DSS Level 1 certified payment gateway. Card, UPI, and banking details never touch our servers.",
      legalEntity: 'Razorpay Software Private Limited',
      issuedBy: 'Razorpay · RBI-regulated payment aggregator',
      scope:
          'UPI, cards, netbanking, wallets, EMI. Every transaction is signature-verified server-side via webhook before an order is marked paid.',
    ),
  ];

  @override
  State<_CertificationsSection> createState() => _CertificationsSectionState();
}

class _CertificationsSectionState extends State<_CertificationsSection> {
  final PageController _pageCtrl = PageController();
  int _index = 0;

  List<List<_CertSpec>> get _slides {
    const perSlide = 4;
    final list = <List<_CertSpec>>[];
    final src = _CertificationsSection._allCerts;
    for (int i = 0; i < src.length; i += perSlide) {
      list.add(src.sublist(i, math.min(i + perSlide, src.length)));
    }
    return list;
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slides = _slides;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF3B0608), Color(0xFF1C0304)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const _CertHeader(),
              // Carousel height is computed from the actual medallion
              // size each device would render, capped at 140 px. A fixed
              // height overflowed on wider phones because AspectRatio(1)
              // made medallions grow unbounded with screen width.
              LayoutBuilder(
                builder: (context, constraints) {
                  // Slide padding (20 LR) + gap between the two columns (14).
                  const horizontalReserve = 20 * 2 + 14;
                  final medallion = math.min<double>(
                    140,
                    (constraints.maxWidth - horizontalReserve) / 2,
                  );
                  // Slide vertical padding (10 top + 6 bottom) + the gap
                  // between the two rows (28) + the two medallion heights.
                  const verticalReserve = 10 + 28 + 6;
                  final height = medallion * 2 + verticalReserve;
                  return SizedBox(
                    height: height,
                    // BE NAYAK is now part of each slide so it swipes with
                    // the medallions — a static center button on top of a
                    // sliding grid felt disjointed. Each page carries its
                    // own branded center mark in the gap between the two
                    // rows of credentials.
                    child: PageView.builder(
                      controller: _pageCtrl,
                      itemCount: slides.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (context, i) => _CertSlide(
                        certs: slides[i],
                        medallionSize: medallion,
                        onTapScan: widget.onTapScan,
                      ),
                    ),
                  );
                },
              ),
              if (slides.length > 1) ...[
                _CertDots(count: slides.length, selected: _index),
                const SizedBox(height: 10),
              ] else
                const SizedBox(height: 8),
              const _CertFooter(),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _CertSpec {
  const _CertSpec({
    required this.category,
    required this.title,
    required this.subtitle,
    required this.chip,
    required this.icon,
    required this.accent,
    required this.fullTitle,
    required this.summary,
    this.legalEntity,
    this.registrationNumber,
    this.issuedBy,
    this.issuedOn,
    this.validUntil,
    this.scope,
  });

  // Fields shown on the medallion itself.
  final String category;
  final String title;
  final String subtitle;
  final String chip;
  final IconData icon;
  final Color accent;

  // Fields shown when the user taps for details. `fullTitle` and `summary`
  // are required so every medallion has something readable in the sheet;
  // the rest are optional because not every registration has the same
  // shape of metadata (some have expiry, some don't, some are temp refs).
  final String fullTitle;
  final String summary;
  final String? legalEntity;
  final String? registrationNumber;
  final String? issuedBy;
  final String? issuedOn;
  final String? validUntil;
  final String? scope;
}

// Header shared by every slide — "GOVT. APPROVED" pill + brand title +
// "VERIFIED CERTIFICATIONS" divider. Kept outside the PageView so it
// doesn't jitter while the user swipes.
class _CertHeader extends StatelessWidget {
  const _CertHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFE28A), Color(0xFFD4A05C)],
              ),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4A05C).withValues(alpha: 0.4),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Text(
              'GOVT. APPROVED & ISO CERTIFIED',
              style: TextStyle(
                color: Color(0xFF3B1E07),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFFFE28A), Color(0xFFD4A05C)],
            ).createShader(bounds),
            child: const Text(
              'QR 4 EMERGENCY',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'CP INFOTECH & CP NETWORK PVT. LTD.',
            style: TextStyle(
              color: Color(0xFFE6C6C9),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: const Color(0xFFD4A05C).withValues(alpha: 0.4),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'VERIFIED CERTIFICATIONS',
                  style: TextStyle(
                    color: Color(0xFFFFE28A),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: const Color(0xFFD4A05C).withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Tap any metallic emblem to inspect official registration & audit credentials',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFE6C6C9),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// One page worth of credentials — up to 4 medallions in a 2×2 grid. The
// center BE NAYAK button is drawn in the parent Stack, not here, so it
// doesn't scroll with the slide. Medallion size is computed by the
// parent LayoutBuilder and passed in so every slide matches the
// carousel's computed height exactly (no fractional-pixel overflow).
class _CertSlide extends StatelessWidget {
  const _CertSlide({
    required this.certs,
    required this.medallionSize,
    required this.onTapScan,
  });
  final List<_CertSpec> certs;
  final double medallionSize;
  final VoidCallback onTapScan;

  _CertSpec? _at(int i) => i < certs.length ? certs[i] : null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _slot(_at(0)),
                  _slot(_at(1)),
                ],
              ),
              // Empty gap in the grid — the BE NAYAK button below is in
              // the Stack's center alignment, so it sits exactly in this
              // vertical window without overlapping the medallions.
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _slot(_at(2)),
                  _slot(_at(3)),
                ],
              ),
            ],
          ),
          _BeNayakCenter(onTap: onTapScan),
        ],
      ),
    );
  }

  Widget _slot(_CertSpec? spec) {
    return SizedBox(
      width: medallionSize,
      height: medallionSize,
      child: spec == null
          ? const SizedBox.shrink()
          : _CertMedallion(spec: spec),
    );
  }
}

// Gold-ringed circular credential tile. All medallions share the same
// gold border so the row reads as one family — the accent color only
// tints the icon and chip so each cert is still visually distinct.
class _CertMedallion extends StatelessWidget {
  const _CertMedallion({required this.spec});
  final _CertSpec spec;

  void _openDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (_) => _CertDetailSheet(spec: spec),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Derive the medallion's dark-tinted background from its accent color
    // so each credential has its own mood — warm brown for amber accents,
    // forest green for emerald, navy for sapphire, etc. Matches the
    // reference design where each circle carries its own color story.
    final bgStart = Color.lerp(spec.accent, const Color(0xFF1A0608), 0.82)!;
    final bgEnd = Color.lerp(spec.accent, const Color(0xFF07070A), 0.92)!;
    return ScaleTap(
      onTap: () => _openDetails(context),
      child: Container(
        // Thicker gold ring than before (4 → 6) — reads as a metal frame
        // rather than a hairline outline, matches the reference.
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFE9A4), Color(0xFFCB9138), Color(0xFF8A5A14)],
            stops: [0.0, 0.55, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD4A05C).withValues(alpha: 0.38),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [bgStart, bgEnd],
            ),
            // Hairline inner gold ring — produces the subtle second ring
            // visible in the reference just inside the main frame.
            border: Border.all(
              color: const Color(0xFFFFE28A).withValues(alpha: 0.22),
              width: 0.8,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                spec.category,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFFFE28A),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 3),
              Icon(spec.icon, color: spec.accent, size: 22),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  spec.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Color(0xFFFFE28A),
                    fontFamily: 'serif',
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                spec.subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFE6C6C9),
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: spec.accent.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: spec.accent.withValues(alpha: 0.6),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  spec.chip,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: spec.accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
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

// Bottom sheet showing the tapped medallion's full registration data —
// legal entity, cert number, issuer, issue + expiry dates, scope, and a
// "verify at source" link to the official registry. Keeps the dark-maroon
// + gold palette so it feels like an extension of the credentials panel.
class _CertDetailSheet extends StatelessWidget {
  const _CertDetailSheet({required this.spec});
  final _CertSpec spec;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.85),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3B0608), Color(0xFF1C0304)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFFFFE28A),
                                Color(0xFFB07A2E),
                              ],
                            ),
                          ),
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFF3F0A0D),
                                  Color(0xFF1F0405),
                                ],
                              ),
                            ),
                            child: Icon(
                              spec.icon,
                              color: spec.accent,
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  spec.category,
                                  style: const TextStyle(
                                    color: Color(0xFFFFE28A),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.3,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                spec.fullTitle,
                                style: const TextStyle(
                                  color: Color(0xFFFFE28A),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  height: 1.25,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                      decoration: BoxDecoration(
                        color: spec.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: spec.accent.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        spec.summary,
                        style: const TextStyle(
                          color: Color(0xFFF3E6E7),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (spec.legalEntity != null)
                      _DetailRow(label: 'Legal entity', value: spec.legalEntity!),
                    if (spec.registrationNumber != null)
                      _DetailRow(
                          label: 'Registration no.',
                          value: spec.registrationNumber!),
                    if (spec.issuedBy != null)
                      _DetailRow(label: 'Issued by', value: spec.issuedBy!),
                    if (spec.issuedOn != null)
                      _DetailRow(label: 'Issued on', value: spec.issuedOn!),
                    if (spec.validUntil != null)
                      _DetailRow(
                          label: 'Valid until', value: spec.validUntil!),
                    if (spec.scope != null)
                      _DetailRow(label: 'Scope', value: spec.scope!),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFD4A05C),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: const TextStyle(
              color: Color(0xFFF3E6E7),
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

// Fixed "BE NAYAK / TAP TO SCAN" button that sits over the center gap of
// the 2×2 grid. Opens the scanner tab on tap (via the callback threaded
// down from HomeTab).
class _BeNayakCenter extends StatelessWidget {
  const _BeNayakCenter({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF26066), Color(0xFFE51E25), Color(0xFFB71218)],
          ),
          border: Border.all(color: const Color(0xFFFFE28A), width: 2.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE51E25).withValues(alpha: 0.6),
              blurRadius: 24,
              spreadRadius: -2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Nayak brand mark replacing the generic scan icon. ClipRRect
            // rounds the JPEG's white background so it reads as a crisp
            // logo badge sitting on the red disc rather than a pasted
            // photo. Kept small so the BE NAYAK + TAP TO SCAN labels
            // below still breathe inside the 96-px circle.
            // Full nayak sticker shown contained inside a small white
            // card so every element of the mark — QR frame, "BE NAYAK"
            // tagline, bottom strip — stays legible. `contain` means the
            // image never gets cropped, it just shrinks until the whole
            // thing fits; the user asked for all the text to be visible
            // even if that makes the logo look small.
            Container(
              width: 34,
              height: 34,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Image.asset(
                'assets/images/nayak.jpeg',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'BE NAYAK',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'TAP TO SCAN',
              style: TextStyle(
                color: Color(0xFFFFE28A),
                fontSize: 7.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Gold pagination dots. Hidden when there's only one slide so the single
// slot doesn't get a lone useless dot.
class _CertDots extends StatelessWidget {
  const _CertDots({required this.count, required this.selected});
  final int count;
  final int selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (i) {
          final active = i == selected;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            height: 6,
            width: active ? 22 : 6,
            decoration: BoxDecoration(
              gradient: active
                  ? const LinearGradient(
                      colors: [Color(0xFFFFE28A), Color(0xFFD4A05C)],
                    )
                  : null,
              color: active
                  ? null
                  : const Color(0xFFD4A05C).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }
}

// Footer tagline that mirrors the sticker's bottom caption. Separates the
// credentials vault visually from whatever sits under it in the scroll.
class _CertFooter extends StatelessWidget {
  const _CertFooter();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A0405), Color(0xFF14181F)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFD4A05C).withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          children: [
            const Text(
              '"Innovation That Leads The Future of Public Safety"',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFFFE28A),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                letterSpacing: 0.3,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'qr4emergency.com · Emergency Vehicle & Personal QR Stickers',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFE6C6C9),
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            // Fine-print IP notice. Sits under a hairline divider so it
            // reads as a legal disclaimer, not as equal-weight content —
            // mandatory on a profile page that references third-party
            // marks (ISO, MSME, GeM, Razorpay, D&B, etc.).
            const SizedBox(height: 12),
            Container(
              height: 0.6,
              width: 80,
              color: const Color(0xFFD4A05C).withValues(alpha: 0.4),
            ),
            const SizedBox(height: 10),
            const Text(
              'Our company is an Intellectual Property Rights Protected '
              'such as Trademarks and copyrights.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFD8B5B8),
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'All company names, logos, trademarks, and registered '
              'trademarks mentioned in this profile are the property of '
              'their respective owners. Use of these names, trademarks, '
              'and brands does not imply endorsement, affiliation, or '
              'sponsorship.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFBF9EA1),
                fontSize: 9,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
                height: 1.5,
              ),
            ),
          ],
        ),
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
