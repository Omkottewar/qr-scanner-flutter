import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/api_client.dart';

class _Slide {
  const _Slide({
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.color,
    required this.gradient,
  });

  final String tag;
  final String title;
  final String subtitle;
  final String imageUrl;
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
      PageController(viewportFraction: _viewportFraction);
  int _index = 0;
  Timer? _autoPlay;

  // Auto-advance every 5 seconds. Pauses while the user is actively
  // dragging via `onNotification`.
  static const Duration _autoPlayInterval = Duration(seconds: 5);
  bool _userIsScrolling = false;

  // Slides come purely from the admin-managed carousel on the backend.
  // We start empty — the parent hides the widget via the itemCount==0
  // guard in build() until GET /api/app/carousel returns something, so
  // users never see stale bundled stock photos.
  List<_Slide> _slides = const [];

  // Width ÷ height of the uploaded banners. Measured from the first
  // slide's image once it loads, so the cards take the real shape of the
  // posters admins upload instead of a guessed one (which cropped text
  // off both edges). 4:3 until the first image is measured.
  double _aspect = 4 / 3;

  // Page width as a fraction of the screen (neighbours peek in), and the
  // gap on each side of a card. Used to size the carousel to the card.
  static const double _viewportFraction = 0.92;
  static const double _cardGap = 6;

  // Reads the first banner's pixel size. Uses the same NetworkImage key
  // as Image.network, so it comes from the image cache — no extra download.
  void _measureAspect(String url) {
    final stream = NetworkImage(url).resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        stream.removeListener(listener);
        final w = info.image.width;
        final h = info.image.height;
        if (!mounted || w <= 0 || h <= 0) return;
        // Clamp so one odd upload can't make the carousel absurdly tall
        // or a thin strip.
        setState(() => _aspect = (w / h).clamp(0.8, 2.4));
      },
      onError: (_, _) => stream.removeListener(listener),
    );
    stream.addListener(listener);
  }

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
    _fetchSlides();
  }

  // Pull slides from the backend so admin can swap images / captions /
  // tags without an app rebuild. Only `tag/title/subtitle/imageUrl` come
  // from the server — the color + gradient palette stays client-side and
  // is picked by index, which keeps the admin surface area tiny while
  // still letting us ship new slides overnight.
  Future<void> _fetchSlides() async {
    try {
      final res = await ApiClient.instance.get(
        '/api/app/carousel',
        auth: false,
      );
      if (!mounted) return;
      if (res is! Map) return;
      final raw = res['items'];
      if (raw is! List || raw.isEmpty) return;

      final parsed = <_Slide>[];
      for (var i = 0; i < raw.length && parsed.length < 10; i++) {
        final item = raw[i];
        if (item is! Map) continue;
        final imageUrl = item['imageUrl']?.toString().trim() ?? '';
        if (imageUrl.isEmpty) continue;
        final palette = _slidePalette[parsed.length % _slidePalette.length];
        parsed.add(_Slide(
          tag: item['tag']?.toString() ?? '',
          title: item['title']?.toString().trim() ?? '',
          subtitle: item['subtitle']?.toString() ?? '',
          imageUrl: imageUrl,
          color: palette.$1,
          gradient: palette.$2,
        ));
      }

      if (parsed.isEmpty || !mounted) return;
      setState(() {
        _slides = parsed;
        if (_index >= parsed.length) _index = 0;
      });
      _measureAspect(parsed.first.imageUrl);
    } catch (_) {
      // Swallow — defaults are already on screen and that's a fine
      // fallback for a pure-cosmetic surface.
    }
  }

  void _startAutoPlay() {
    _autoPlay?.cancel();
    _autoPlay = Timer.periodic(_autoPlayInterval, (_) {
      if (!mounted || _userIsScrolling || !_controller.hasClients) return;
      final next = (_index + 1) % _slides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  // Color + gradient pairs used when slides come from the backend. Indexed
  // by position so admin never has to think about styling — they just send
  // text and an image URL.
  static const List<(Color, List<Color>)> _slidePalette = [
    (Color(0xFFFF3B30), [Color(0xFF8B0000), Color(0xFF0F1626)]),
    (Color(0xFF8B5CF6), [Color(0xFF4C1D95), Color(0xFF0F1626)]),
    (Color(0xFF14B8A6), [Color(0xFF134E4A), Color(0xFF0F1626)]),
    (Color(0xFFFFB547), [Color(0xFF7A5210), Color(0xFF0F1626)]),
    (Color(0xFF10B981), [Color(0xFF064E3B), Color(0xFF0F1626)]),
    (Color(0xFF3B82F6), [Color(0xFF1E3A8A), Color(0xFF0F1626)]),
  ];

  @override
  void dispose() {
    _autoPlay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Nothing to show until admin uploads carousel slides — collapse the
    // whole widget (parent _BannerCard renders as an empty strip, which
    // the home scroll absorbs without a visible gap).
    if (_slides.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        // Height is derived from the CARD width (not the screen width) and
        // the banners' real aspect ratio, so each card has exactly the
        // shape of the uploaded image. Previously a 4:3 box held cards
        // only ~92% as wide, so every banner was cropped at the sides.
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth =
                constraints.maxWidth * _viewportFraction - _cardGap * 2;
            return SizedBox(
              height: cardWidth / _aspect,
              child: NotificationListener<ScrollNotification>(
            // Pause auto-advance while the user is interacting with the
            // carousel. Resume once the gesture ends so the slideshow
            // keeps cycling in the background.
            onNotification: (n) {
              if (n is ScrollStartNotification) {
                _userIsScrolling = true;
              } else if (n is ScrollEndNotification) {
                _userIsScrolling = false;
              }
              return false;
            },
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _index = i),
              itemCount: _slides.length,
              itemBuilder: (context, i) {
                final slide = _slides[i];
                // Parallax-ish zoom: the active page sits at scale 1.0,
                // neighbours ease down to 0.92. Uses AnimatedBuilder on
                // the PageController so it tracks drag in real time.
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    double offset = 0;
                    if (_controller.position.haveDimensions) {
                      offset = (_controller.page ?? _index.toDouble()) - i;
                    }
                    final scale =
                        (1 - (offset.abs() * 0.08)).clamp(0.92, 1.0);
                    return Center(
                      child: Transform.scale(
                        scale: scale,
                        child: child,
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _cardGap),
                    child: _SlideCard(slide: slide, isFirst: i == 0),
                  ),
                );
              },
            ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_slides.length, (i) {
            final selected = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: selected ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                gradient: selected ? AppColors.brandGradient : null,
                color: selected
                    ? null
                    : AppColors.textTertiary.withValues(alpha: 0.3),
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
    // Image-only slides are finished posters (text, logos, phone mock-ups)
    // uploaded by the admin. Show them exactly as designed: the whole
    // image, on white, with no tint or accent strip painted over it.
    if (slide.title.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: ColoredBox(
          color: Colors.white,
          child: _SlideBackground(
            slide: slide,
            showShieldOnError: isFirst,
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: slide.gradient,
          ),
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
            // Bottom dark gradient — only rendered when there's text to
            // read. Pure-image slides stay crisp instead of getting an
            // unexplained dark wash on the bottom half.
            if (slide.title.isNotEmpty)
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
            // Chip + title + subtitle. Skipped entirely when the slide
            // has no title — otherwise the empty tag container renders
            // as a tiny colored pill over the photo (the "blob"
            // artifact on image-only admin uploads).
            if (slide.title.isNotEmpty)
              Positioned(
                left: 20,
                right: 20,
                bottom: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (slide.tag.isNotEmpty) ...[
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
                    ],
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
                    if (slide.subtitle.isNotEmpty) ...[
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
  const _SlideBackground({
    required this.slide,
    required this.showShieldOnError,
    this.fit = BoxFit.cover,
  });
  final _Slide slide;
  final bool showShieldOnError;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return _NetworkBg(
        slide: slide, showShieldOnError: showShieldOnError, fit: fit);
  }
}

class _NetworkBg extends StatelessWidget {
  const _NetworkBg({
    required this.slide,
    required this.showShieldOnError,
    required this.fit,
  });
  final _Slide slide;
  final bool showShieldOnError;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      slide.imageUrl,
      // The carousel is sized to the banners' measured aspect ratio, so
      // a banner of that shape fills the card exactly. Poster slides use
      // `contain` so a banner of a different shape is shown whole (with
      // a thin white margin) rather than having its text cropped.
      fit: fit,
      width: double.infinity,
      height: double.infinity,
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
