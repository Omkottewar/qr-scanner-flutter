import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class EaCard extends StatelessWidget {
  const EaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.border,
    this.background,
    this.borderRadius = 22,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Border? border;
  final Color? background;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        gradient: background == null ? AppColors.surfaceGradient : null,
        color: background,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? Border.all(color: AppColors.hairline, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}
