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
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF131A2B),
                    Color(0xFF0A0F1D),
                    Color(0xFF06090F),
                  ],
                  stops: [0, 0.5, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -60,
            child: GlowOrb(color: AppColors.primary.withValues(alpha: 0.55), size: 280),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: GlowOrb(color: AppColors.violet.withValues(alpha: 0.32), size: 320),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}
