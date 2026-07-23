import 'package:flutter/material.dart';

// Zero-dependency shimmer used for skeleton loading states. Paints a
// rounded rectangle that sweeps a diagonal light band left→right on a
// 1.4s loop. Cheaper than adding the `shimmer` package and stays
// on-brand because the highlight colour is tuned to the dark navy
// background used across the app.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  static const _base = Color(0xFF1A2236);
  static const _highlight = Color(0xFF243049);

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
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
        // Slide the gradient's `begin`/`end` alignment across [-2, +2]
        // so the highlight band exits fully off the right before
        // re-entering from the left — no visible seam.
        final t = _c.value * 4 - 2;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(t - 1, 0),
              end: Alignment(t + 1, 0),
              colors: const [_base, _highlight, _base],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Standard QR-card skeleton — matches the outer shape of a real QR
/// history card so the layout doesn't jump when the data arrives.
class QrCardSkeleton extends StatelessWidget {
  const QrCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1626),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ShimmerBox(width: 56, height: 56, borderRadius: 14),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    ShimmerBox(width: 140, height: 14),
                    SizedBox(height: 8),
                    ShimmerBox(width: 90, height: 10),
                  ],
                ),
              ),
              const ShimmerBox(width: 60, height: 22, borderRadius: 11),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(child: ShimmerBox(width: double.infinity, height: 36)),
              SizedBox(width: 8),
              Expanded(child: ShimmerBox(width: double.infinity, height: 36)),
            ],
          ),
        ],
      ),
    );
  }
}
