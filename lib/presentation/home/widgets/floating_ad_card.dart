import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';

// Floating promotional card that can show EITHER a still image OR a muted
// autoplay video. Draggable around the screen, dismissable, and entrance-
// animated. The parent MUST host it inside a Stack — the widget returns
// a `Positioned`.
//
// Pass exactly one of [imageUrl] / [imageAsset] / [videoUrl]:
//   • imageAsset → bundled asset image (e.g. 'assets/images/offer.jpg')
//   • imageUrl   → remote image fetched via Image.network
//   • videoUrl   → remote mp4 played muted + looping with simple controls
class FloatingAdCard extends StatefulWidget {
  const FloatingAdCard({
    super.key,
    this.imageAsset,
    this.imageUrl,
    this.videoUrl,
    this.caption,
    this.initialOffset,
    this.width = 180,
    this.onDismiss,
  }) : assert(
          (imageAsset != null ? 1 : 0) +
                  (imageUrl != null ? 1 : 0) +
                  (videoUrl != null ? 1 : 0) ==
              1,
          'Pass exactly one of imageAsset / imageUrl / videoUrl',
        );

  final String? imageAsset;
  final String? imageUrl;
  final String? videoUrl;
  final String? caption;
  final Offset? initialOffset;
  final double width;
  // Fires after the dismiss animation completes. Parents use this to
  // persist the dismissal (e.g. store the creative's URL so the same
  // ad isn't shown again on next launch).
  final VoidCallback? onDismiss;

  @override
  State<FloatingAdCard> createState() => _FloatingAdCardState();
}

class _FloatingAdCardState extends State<FloatingAdCard>
    with SingleTickerProviderStateMixin {
  bool _dismissed = false;
  late Offset _offset;
  VideoPlayerController? _video;
  bool _videoReady = false;

  late final AnimationController _entry;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _offset = widget.initialOffset ?? const Offset(16, 140);
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _scale = CurvedAnimation(parent: _entry, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _entry, curve: Curves.easeOut);
    _entry.forward();
    _initVideoIfNeeded();
  }

  Future<void> _initVideoIfNeeded() async {
    final url = widget.videoUrl;
    if (url == null) return;
    try {
      final v = VideoPlayerController.networkUrl(Uri.parse(url));
      await v.initialize();
      if (!mounted) {
        v.dispose();
        return;
      }
      v.setLooping(true);
      v.setVolume(0);
      v.play();
      setState(() {
        _video = v;
        _videoReady = true;
      });
    } catch (_) {
      // swallow — card just stays image-less; nothing worth surfacing
    }
  }

  @override
  void dispose() {
    _entry.dispose();
    _video?.dispose();
    super.dispose();
  }

  void _dismiss() {
    _entry.reverse().whenComplete(() {
      if (mounted) setState(() => _dismissed = true);
      widget.onDismiss?.call();
    });
    _video?.pause();
  }

  void _onDrag(DragUpdateDetails d, Size size) {
    final screen = MediaQuery.of(context).size;
    final nx = (_offset.dx + d.delta.dx).clamp(0.0, screen.width - size.width);
    final ny = (_offset.dy + d.delta.dy).clamp(0.0, screen.height - size.height);
    setState(() => _offset = Offset(nx, ny));
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) {
      return const Positioned(left: 0, top: 0, child: SizedBox.shrink());
    }

    final width = widget.width;
    // Choose aspect based on content: 16:9 for video, 4:5 (portrait) for
    // static image ads so they feel like a social-feed banner.
    final isVideo = widget.videoUrl != null;
    final aspect = isVideo
        ? (_videoReady && (_video?.value.aspectRatio ?? 0) > 0
            ? _video!.value.aspectRatio
            : 16 / 9)
        : 4 / 5;
    final mediaHeight = width / aspect;
    final captionHeight = widget.caption != null ? 36.0 : 0.0;
    final size = Size(width, mediaHeight + captionHeight);

    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: GestureDetector(
            onPanUpdate: (d) => _onDrag(d, size),
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: Material(
                color: Colors.transparent,
                elevation: 10,
                borderRadius: BorderRadius.circular(16),
                shadowColor: Colors.black.withValues(alpha: 0.4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: width,
                        height: mediaHeight,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildMedia(),
                            // "AD" chip top-left
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'AD',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                            // Close X top-right
                            Positioned(
                              top: 6,
                              right: 6,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _dismiss,
                                child: Container(
                                  width: 26,
                                  height: 26,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.caption != null)
                        Container(
                          height: captionHeight,
                          width: width,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          color: AppColors.primary,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.caption!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMedia() {
    if (widget.imageAsset != null) {
      return Image.asset(
        widget.imageAsset!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _mediaPlaceholder(),
      );
    }
    if (widget.imageUrl != null) {
      return Image.network(
        widget.imageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (c, child, p) => p == null ? child : _mediaPlaceholder(),
        errorBuilder: (_, _, _) => _mediaPlaceholder(),
      );
    }
    if (_videoReady && _video != null) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _video!.value.size.width,
          height: _video!.value.size.height,
          child: VideoPlayer(_video!),
        ),
      );
    }
    return _mediaPlaceholder();
  }

  Widget _mediaPlaceholder() {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.brandGradient),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_rounded,
        color: Colors.white54,
        size: 36,
      ),
    );
  }
}
