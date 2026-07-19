import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class PremiumHeroHeader extends StatelessWidget {
  const PremiumHeroHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.padding =
        const EdgeInsets.fromLTRB(20, 16, 20, 20),
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF101729), Color(0x0006090F)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            ?leading,
            if (leading != null) const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (subtitle != null)
                    Text(
                      subtitle!.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.amber,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  if (subtitle != null) const SizedBox(height: 4),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class GlowOrb extends StatelessWidget {
  const GlowOrb({
    super.key,
    required this.color,
    this.size = 220,
    this.blur = 90,
  });

  final Color color;
  final double size;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.55), Colors.transparent],
            stops: const [0, 1],
          ),
        ),
      ),
    );
  }
}
