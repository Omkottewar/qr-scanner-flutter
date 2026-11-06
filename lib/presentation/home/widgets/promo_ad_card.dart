import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/api_client.dart';
import 'floating_ad_card.dart';

// Fetches the currently-active ad from GET /api/app/promo-video and renders
// it as a draggable [FloatingAdCard]. One floating ad at a time, controlled
// entirely by the backend admin panel:
//
//   • Admin uploads a new MP4 / JPG / PNG via admin.html → the file lands
//     in Supabase storage, the URL is written to the promo_video DB row.
//   • The app opens → PromoAdCard calls GET /api/app/promo-video → gets
//     back {url, title, subtitle} (or {url: null} when nothing is set).
//   • URL ends in .mp4/.webm/.mov → played as muted autoplay video.
//     Otherwise → rendered as an image.
//   • Admin deletes the row → endpoint returns null → PromoAdCard renders
//     nothing.
//   • User dismisses the card → we persist that URL in SharedPreferences
//     so the same creative isn't shown again on later launches. Uploading
//     a NEW creative changes the URL, which resets the dismissal.
//
// This widget MUST be used as a direct child of a Stack — it returns a
// Positioned widget sized to the floating-card hit box.
class PromoAdCard extends StatefulWidget {
  const PromoAdCard({super.key, this.initialOffset, this.width = 180});

  final Offset? initialOffset;
  final double width;

  @override
  State<PromoAdCard> createState() => _PromoAdCardState();
}

// SharedPreferences key holding the URL of the last-dismissed creative.
// One slot (not a list) — dismissing the active ad only needs to remember
// THAT one; older creatives are gone from Supabase anyway.
const String _kDismissedUrlKey = 'promo_ad_dismissed_url';

// File extensions that trigger the video pipeline. Everything else is
// treated as an image. Matches what the admin upload route accepts
// (admin.routes.js regex).
const _videoExts = {'.mp4', '.webm', '.mov'};

class _PromoAdCardState extends State<PromoAdCard> {
  bool _loading = true;
  bool _dismissed = false;
  String? _url;
  String? _caption;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.get(
        '/api/app/promo-video',
        auth: false,
      );
      if (!mounted) return;

      if (res is! Map || res['url'] == null) {
        setState(() {
          _loading = false;
          _url = null;
        });
        return;
      }

      final url = res['url'].toString().trim();
      if (url.isEmpty) {
        setState(() {
          _loading = false;
          _url = null;
        });
        return;
      }

      // Caption falls back through title → subtitle → nothing. "Learn more"
      // is a reasonable default only if admin left both empty.
      final title = res['title']?.toString().trim() ?? '';
      final subtitle = res['subtitle']?.toString().trim() ?? '';
      final caption = title.isNotEmpty
          ? title
          : subtitle.isNotEmpty
              ? subtitle
              : null;

      // Was this exact URL already dismissed in a prior session? Skip
      // the floating card entirely — no network fetch of the media, no
      // controller allocated.
      final prefs = await SharedPreferences.getInstance();
      final dismissedFor = prefs.getString(_kDismissedUrlKey);

      if (!mounted) return;
      setState(() {
        _loading = false;
        _url = url;
        _caption = caption;
        _dismissed = dismissedFor == url;
      });
    } catch (_) {
      // Network error or shape mismatch — render nothing. A broken ad
      // pipeline must never block the rest of the home page.
      if (mounted) {
        setState(() {
          _loading = false;
          _url = null;
        });
      }
    }
  }

  Future<void> _persistDismissal() async {
    final url = _url;
    if (url == null || url.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDismissedUrlKey, url);
    } catch (_) {
      // Dismissal didn't persist — it stays hidden for this session,
      // which is the important part. Next launch will show it again.
    }
  }

  bool get _isVideoUrl {
    final u = _url;
    if (u == null) return false;
    // Strip query string before extension match — Supabase signed URLs
    // can have a ?token=… suffix.
    final path = Uri.tryParse(u)?.path.toLowerCase() ?? u.toLowerCase();
    return _videoExts.any(path.endsWith);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _dismissed || _url == null) {
      return const Positioned(left: 0, top: 0, child: SizedBox.shrink());
    }

    return FloatingAdCard(
      key: ValueKey(_url),
      imageUrl: _isVideoUrl ? null : _url,
      videoUrl: _isVideoUrl ? _url : null,
      caption: _caption,
      width: widget.width,
      initialOffset: widget.initialOffset,
      onDismiss: _persistDismissal,
    );
  }
}
