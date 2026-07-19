import 'package:flutter/material.dart';

abstract final class AppColors {
  // Brand
  static const Color primary = Color(0xFFFF7A00);
  static const Color primaryDeep = Color(0xFFE05A00);
  static const Color orange = Color(0xFFE56B1A);
  static const Color amber = Color(0xFFFFB547);

  // Surfaces
  static const Color background = Color(0xFF06090F);
  static const Color backgroundElevated = Color(0xFF0E1422);
  static const Color card = Color(0xFF131A2B);
  static const Color cardHigh = Color(0xFF1A2238);
  static const Color inputFill = Color(0xFF1A2236);

  // Glass
  static const Color glassFill = Color(0x14FFFFFF);
  static const Color glassStroke = Color(0x1AFFFFFF);
  static const Color hairline = Color(0x14FFFFFF);

  // Text
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textTertiary = Color(0xFF64748B);

  // Status
  static const Color stepGreen = Color(0xFF10B981);
  static const Color blue = Color(0xFF3B82F6);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color red = Color(0xFFEF4444);

  // Info banner (legacy)
  static const Color infoOrangeBg = Color(0xFF2C1A10);
  static const Color infoOrangeText = Color(0xFFFFAD73);

  // Gradients
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF9A45), Color(0xFFFF6A00), Color(0xFFE25500)],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient brandGradientSubtle = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x33FF9A45), Color(0x14FF6A00)],
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF161F33), Color(0xFF0F1626)],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0E1422), Color(0xFF06090F)],
  );
}
