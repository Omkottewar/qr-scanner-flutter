import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'premium_hero_header.dart';

class LoginGradientBackground extends StatelessWidget {
  const LoginGradientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppColors.backgroundGradient,
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -60,
            child: GlowOrb(color: AppColors.primary.withValues(alpha: 0.18), size: 280),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: GlowOrb(color: AppColors.amber.withValues(alpha: 0.14), size: 320),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}
