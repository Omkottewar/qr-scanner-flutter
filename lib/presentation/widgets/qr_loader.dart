import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

// Simple shimmer-rect loader. One widget covers every call site: a
// rounded rectangle that sweeps a diagonal highlight across its surface
// on a short loop. Fast to render, reads clearly on any background, no
// per-pixel animation work.
//
// Sized by `size` for square usages (defaults to a sensible 44). For
// skeleton rows, pass explicit `width` / `height`.
class QrLoader extends StatefulWidget {
  const QrLoader({
    super.key,
    this.size = 44,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.color,
  });

  final double size;
  final double? width;
  final double? height;
  final double borderRadius;
  final Color? color;

  @override
  State<QrLoader> createState() => _QrLoaderState();
}

class _QrLoaderState extends State<QrLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.width ?? widget.size;
    final h = widget.height ?? widget.size;
    final base = widget.color ?? const Color(0xFFE9EBF2);
    final highlight = const Color(0xFFF6F7FB);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value * 4 - 2;
        return Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(t - 1, 0),
              end: Alignment(t + 1, 0),
              colors: [base, highlight, base],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

// Full-screen boot loader: brand logo + wordmark on a quiet background
// with a thin shimmer bar underneath. Replaces the heavy sticker loader
// that was pegging the frame budget on real hardware.
class QrBootLoader extends StatelessWidget {
  const QrBootLoader({super.key, this.status = 'Loading'});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 24,
                  spreadRadius: -4,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/nayak.jpeg',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  decoration: const BoxDecoration(
                    gradient: AppColors.brandGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'QR 4 Emergency',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 24),
          const QrLoader(width: 160, height: 4, borderRadius: 2),
          const SizedBox(height: 12),
          Text(
            status,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
