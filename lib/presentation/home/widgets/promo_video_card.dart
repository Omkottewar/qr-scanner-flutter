import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/api_client.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/scale_tap.dart';

// Renders whatever HTTPS MP4 the backend hands out at
// GET /api/app/promo-video. If the endpoint returns `{ url: null }` the
// section renders nothing at all — safe for local dev and unconfigured
// deployments. Backed by video_player; play/pause overlay, tap-to-toggle.
class PromoVideoCard extends StatefulWidget {
  const PromoVideoCard({super.key});

  @override
  State<PromoVideoCard> createState() => _PromoVideoCardState();
}

class _PromoVideoCardState extends State<PromoVideoCard> {
  bool _loading = true;
  String? _url;
  String _title = '';
  String _subtitle = '';
  VideoPlayerController? _controller;
  bool _controllerReady = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.get('/api/app/promo-video', auth: false);
      if (!mounted) return;
      if (res is! Map || res['url'] == null) {
        setState(() {
          _loading = false;
          _url = null;
        });
        return;
      }
      final url = '${res['url']}';
      final title = res['title'] == null ? '' : '${res['title']}';
      final subtitle = res['subtitle'] == null ? '' : '${res['subtitle']}';
      // Dispose any previously-created controller before replacing it —
      // otherwise a hot-reload / retry leaks the old one.
      final oldCtrl = _controller;
      _controller = null;
      _controllerReady = false;
      oldCtrl?.dispose();

      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      ctrl.setLooping(false);
      ctrl.addListener(() {
        if (mounted) setState(() {});
      });
      setState(() {
        _url = url;
        _title = title;
        _subtitle = subtitle;
        _controller = ctrl;
        _controllerReady = true;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[promo-video] load failed: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _url = null;
        });
      }
    }
  }

  void _toggle() {
    final c = _controller;
    if (c == null || !_controllerReady) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      if (c.value.position >= c.value.duration) {
        c.seekTo(Duration.zero);
      }
      c.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox.shrink();
    }
    if (_url == null || _controller == null || !_controllerReady) {
      return const SizedBox.shrink();
    }

    final c = _controller!;
    final isPlaying = c.value.isPlaying;
    final aspect = c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_title.isNotEmpty)
            Text(
              _title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          if (_subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              _subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 12),
          GlassCard(
            padding: EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: aspect,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPlayer(c),
                    // Progress bar pinned to the bottom.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: VideoProgressIndicator(
                        c,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: AppColors.primary,
                          bufferedColor: Colors.white24,
                          backgroundColor: Colors.white10,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                      ),
                    ),
                    // Tap surface + play/pause overlay.
                    Positioned.fill(
                      child: ScaleTap(
                        onTap: _toggle,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: isPlaying ? 0.0 : 1.0,
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.28),
                            alignment: Alignment.center,
                            child: Container(
                              width: 64,
                              height: 64,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.95),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    blurRadius: 22,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Color(0xFF7A3500),
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
