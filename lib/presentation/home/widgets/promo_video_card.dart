import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/api_client.dart';

// Floating draggable ad-video overlay. Renders whatever HTTPS MP4 the
// backend hands out at GET /api/app/promo-video. If the endpoint returns
// `{ url: null }` the widget renders nothing at all — safe for local dev
// and unconfigured deployments.
//
// Behaviour matches a mini/picture-in-picture player:
//   • Card floats over the home tab content, positioned via `Positioned`
//     inside the parent Stack.
//   • Whole card is draggable — pan updates the tracked offset via
//     `setState`; the VideoPlayerController is NEVER touched, so the
//     video keeps playing throughout the drag (no restarts).
//   • On-video controls (bottom bar): play / pause and mute. X button
//     top-right dismisses and persists dismissal keyed on the URL.
//   • Progress bar pinned to the bottom of the video.
//
// This widget MUST be used as a direct child of a Stack — it returns
// a `Positioned` for the parent to place.
class PromoVideoCard extends StatefulWidget {
  const PromoVideoCard({super.key, this.initialOffset});

  // Starting position for the floating card. If null, defaults to the
  // top-left area (16, 120) — under the top bar, on the left edge, so
  // the user notices the ad immediately.
  final Offset? initialOffset;

  @override
  State<PromoVideoCard> createState() => _PromoVideoCardState();
}

// SharedPreferences key holding the URL of the last-dismissed promo.
// One slot, not a list — a user who dismisses the current ad only
// needs to remember THAT one; older dismissals aren't interesting.
const String _kDismissedUrlKey = 'promo_video_dismissed_url';

// Fixed on-screen size for the floating card. Small enough to leave the
// home content readable, big enough that the video is watchable.
const double _kCardWidth = 200;

class _PromoVideoCardState extends State<PromoVideoCard> {
  bool _loading = true;
  bool _dismissed = false;
  String? _url;
  VideoPlayerController? _controller;
  bool _controllerReady = false;

  // Position of the top-left corner of the floating card, in local
  // coordinates of the parent Stack. Updated on drag via setState —
  // the VideoPlayerController is untouched, so playback continues
  // seamlessly through the drag gesture.
  late Offset _offset;

  @override
  void initState() {
    super.initState();
    _offset = widget.initialOffset ?? const Offset(16, 120);
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

      // Check if the user previously dismissed THIS exact URL. If so,
      // skip initialising the video player entirely — no bytes fetched,
      // no controller allocated, nothing rendered.
      final prefs = await SharedPreferences.getInstance();
      final dismissedUrl = prefs.getString(_kDismissedUrlKey);
      if (dismissedUrl == url) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _dismissed = true;
          _url = url;
        });
        return;
      }

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

  // Dismiss the ad card. Persists the current URL so it stays hidden
  // across app restarts. Uploading a NEW video changes the URL and the
  // user sees the fresh ad again — same UX as Zepto/Blinkit banners.
  Future<void> _dismiss() async {
    final url = _url;
    setState(() {
      _dismissed = true;
    });
    _controller?.pause();
    if (url == null || url.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDismissedUrlKey, url);
    } catch (e) {
      // Storage write failed — the card is still hidden for this
      // session; the user can dismiss it again next time.
      debugPrint('[promo-video] dismiss persist failed: $e');
    }
  }

  void _togglePlay() {
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

  void _toggleMute() {
    final c = _controller;
    if (c == null || !_controllerReady) return;
    final currentlyMuted = c.value.volume == 0.0;
    c.setVolume(currentlyMuted ? 1.0 : 0.0);
    setState(() {});
  }

  // Drag handler — only updates the tracked offset. VideoPlayerController
  // is completely untouched, so playback is seamless. Clamped to keep
  // the card fully on-screen so the user can't drag it out of reach.
  void _onDragUpdate(DragUpdateDetails details, Size cardSize) {
    final screen = MediaQuery.of(context).size;
    final newDx = (_offset.dx + details.delta.dx)
        .clamp(0.0, screen.width - cardSize.width);
    final newDy = (_offset.dy + details.delta.dy)
        .clamp(0.0, screen.height - cardSize.height);
    setState(() {
      _offset = Offset(newDx, newDy);
    });
  }

  @override
  Widget build(BuildContext context) {
    // While loading, dismissed, or missing video — render an empty
    // positioned box so the parent Stack layout doesn't shift.
    if (_loading || _dismissed || _url == null ||
        _controller == null || !_controllerReady) {
      return const Positioned(
        left: 0,
        top: 0,
        child: SizedBox.shrink(),
      );
    }

    final c = _controller!;
    final isPlaying = c.value.isPlaying;
    final isMuted = c.value.volume == 0.0;
    final aspect = c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio;

    final cardHeight = _kCardWidth / aspect + 32; // + control bar
    final cardSize = Size(_kCardWidth, cardHeight);

    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: GestureDetector(
        // Drag anywhere on the card body (below the control buttons)
        // moves the card. Buttons have their own GestureDetectors that
        // stop propagation so tapping them doesn't also drag.
        onPanUpdate: (d) => _onDragUpdate(d, cardSize),
        child: SizedBox(
          width: _kCardWidth,
          height: cardHeight,
          child: Material(
            color: Colors.transparent,
            elevation: 8,
            borderRadius: BorderRadius.circular(14),
            shadowColor: Colors.black.withValues(alpha: 0.55),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Video + overlays (progress bar, dismiss X)
                  AspectRatio(
                    aspectRatio: aspect,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        VideoPlayer(c),
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
                            padding: const EdgeInsets.symmetric(vertical: 3),
                          ),
                        ),
                        // X (dismiss) — top-right.
                        Positioned(
                          top: 6,
                          right: 6,
                          child: _RoundIconButton(
                            icon: Icons.close_rounded,
                            onTap: _dismiss,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Control bar — play/pause + mute. Sits BELOW the
                  // video so tapping controls never lands on the drag
                  // surface (the video area).
                  Container(
                    height: 32,
                    color: Colors.black.withValues(alpha: 0.9),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Row(
                      children: [
                        _BarIconButton(
                          icon: isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          onTap: _togglePlay,
                        ),
                        const SizedBox(width: 6),
                        _BarIconButton(
                          icon: isMuted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          onTap: _toggleMute,
                        ),
                        const Spacer(),
                        // Drag hint — subtle grip icon on the right of
                        // the bar hinting the card is movable.
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.drag_indicator_rounded,
                            color: Colors.white38,
                            size: 18,
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
      ),
    );
  }
}

// Compact circular icon button used for the X dismiss affordance.
// Its own GestureDetector consumes taps so they don't propagate to the
// underlying pan handler on the card.
class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}

// Icon button used inside the bottom control bar.
class _BarIconButton extends StatelessWidget {
  const _BarIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 26,
        height: 26,
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
