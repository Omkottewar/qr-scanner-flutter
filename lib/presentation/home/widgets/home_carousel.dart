import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class _Slide {
  const _Slide({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.color,
    required this.gradient,
    this.assetPath,
  });

  final String tag;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String? assetPath;
  final Color color;
  final List<Color> gradient;
}

class HomeCarousel extends StatefulWidget {
  const HomeCarousel({super.key});

  @override
  State<HomeCarousel> createState() => _HomeCarouselState();
}

class _HomeCarouselState extends State<HomeCarousel> {
  final PageController _controller =
      PageController(viewportFraction: 0.92);
  int _index = 0;

  // Each slide pairs a caption with a topical image. Local assets win when
  // present; otherwise a specific Unsplash CDN URL (not a random service) is
  // used so the photo always matches the caption.
  static const List<_Slide> _slides = [
    _Slide(
      tag: 'ACCIDENT EMERGENCY',
      title: 'In a crash? Your family knows in seconds.',
      subtitle:
          'Any bystander can scan your QR and reach your trusted contacts — no number lookups, no delays.',
      imageUrl:
          'https://images.unsplash.com/photo-1713623311317-d3c43a4be4cf?w=900&q=80&auto=format&fit=crop',
      assetPath: 'assets/images/accident.png',
      color: Color(0xFFFF3B30),
      gradient: [Color(0xFF8B0000), Color(0xFF0F1626)],
    ),
    _Slide(
      tag: 'TRUSTED CONTACTS',
      title: 'Five trusted contacts. One QR scan.',
      subtitle:
          'Instantly connect with your family, friends, or emergency contacts when every second matters.',
      imageUrl:
          'https://plus.unsplash.com/premium_photo-1745299853417-b13c4e281c31?w=900&q=80&auto=format&fit=crop',
      color: Color(0xFF8B5CF6),
      gradient: [Color(0xFF4C1D95), Color(0xFF0F1626)],
    ),
    _Slide(
      tag: 'CALL MASKING',
      title: 'They call you. Without ever seeing your number.',
      subtitle:
          'Every emergency call is bridged through our secure layer — your real phone number stays hidden, on both sides.',
      imageUrl:
          'https://plus.unsplash.com/premium_photo-1700592623848-91fc17d2592d?w=900&q=80&auto=format&fit=crop',
      color: Color(0xFF14B8A6),
      gradient: [Color(0xFF134E4A), Color(0xFF0F1626)],
    ),
    _Slide(
      tag: 'WRONG PARKING',
      title: "Blocked someone? They reach you privately.",
      subtitle:
          'No more notes under wipers. A quick scan triggers a masked call — your number stays private.',
      imageUrl:
          'https://images.unsplash.com/photo-1658260867231-535a1f7c98b9?w=900&q=80&auto=format&fit=crop',
      assetPath: 'assets/images/no_parking.png',
      color: Color(0xFFFFB547),
      gradient: [Color(0xFF7A5210), Color(0xFF0F1626)],
    ),
    _Slide(
      tag: 'SPAM PROTECTION',
      title: 'See caller location. Block spam in one tap.',
      subtitle:
          'View where each scan happened, and block any number that calls you too often — right from the app.',
      imageUrl:
          'https://images.unsplash.com/photo-1526628953301-3e589a6a8b74?w=900&q=80&auto=format&fit=crop',
      color: Color(0xFF10B981),
      gradient: [Color(0xFF064E3B), Color(0xFF0F1626)],
    ),
    _Slide(
      tag: 'ROAD SAFETY',
      title: 'Drive easy. Help is one scan away.',
      subtitle:
          'Highways, late nights, long trips — you are never truly alone behind the wheel.',
      imageUrl:
          'https://images.unsplash.com/photo-1741122433084-002301210c13?w=900&q=80&auto=format&fit=crop',
      color: Color(0xFF3B82F6),
      gradient: [Color(0xFF1E3A8A), Color(0xFF0F1626)],
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: _slides.length,
            itemBuilder: (context, i) {
              final slide = _slides[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _SlideCard(slide: slide, isFirst: i == 0),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_slides.length, (i) {
            final selected = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: selected ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                gradient: selected ? AppColors.brandGradient : null,
                color: selected
                    ? null
                    : Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _SlideCard extends StatelessWidget {
  const _SlideCard({required this.slide, required this.isFirst});
  final _Slide slide;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: slide.gradient,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background photo (falls back to the gradient + ping shield)
            _SlideBackground(slide: slide, showShieldOnError: isFirst),
            // Color tint on top of the photo so the brand colour bleeds through
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        slide.gradient.first.withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Left edge color glow strip
            Positioned(
              left: 0,
              top: 24,
              bottom: 24,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: slide.color,
                  borderRadius:
                      const BorderRadius.horizontal(right: Radius.circular(2)),
                  boxShadow: [
                    BoxShadow(
                      color: slide.color,
                      blurRadius: 16,
                    ),
                  ],
                ),
              ),
            ),
            // Bottom dark gradient so text reads on any photo
            const Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x33000000),
                        Color(0xE6000000),
                      ],
                      stops: [0.25, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            // Chip + title + subtitle
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: slide.color.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: slide.color.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      slide.tag,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    slide.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    slide.subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideBackground extends StatelessWidget {
  const _SlideBackground({required this.slide, required this.showShieldOnError});
  final _Slide slide;
  final bool showShieldOnError;

  @override
  Widget build(BuildContext context) {
    final asset = slide.assetPath;
    if (asset != null) {
      return Image.asset(
        asset,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stack) => _NetworkBg(
          slide: slide,
          showShieldOnError: showShieldOnError,
        ),
      );
    }
    return _NetworkBg(slide: slide, showShieldOnError: showShieldOnError);
  }
}

class _NetworkBg extends StatelessWidget {
  const _NetworkBg({required this.slide, required this.showShieldOnError});
  final _Slide slide;
  final bool showShieldOnError;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      slide.imageUrl,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _Fallback(slide: slide, showShield: showShieldOnError);
      },
      errorBuilder: (context, error, stack) =>
          _Fallback(slide: slide, showShield: showShieldOnError),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.slide, required this.showShield});
  final _Slide slide;
  final bool showShield;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: slide.gradient,
        ),
      ),
      child: showShield
          ? const Center(child: _PingShield())
          : Center(
              child: Opacity(
                opacity: 0.18,
                child: Icon(
                  Icons.image_outlined,
                  size: 56,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ),
    );
  }
}

class _PingShield extends StatefulWidget {
  const _PingShield();

  @override
  State<_PingShield> createState() => _PingShieldState();
}

class _PingShieldState extends State<_PingShield>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        return SizedBox(
          width: 200,
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Ping ring
              Opacity(
                opacity: (1 - t).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.6 + t * 1.4,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              // Central shield
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.shield_rounded,
                      color: Colors.white, size: 48),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
