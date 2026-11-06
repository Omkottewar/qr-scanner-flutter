import 'package:flutter/material.dart';

abstract final class AppColors {
  // Brand — matches the red used on the downloadable QR sticker so the
  // app chrome and the physical product read as one family.
  static const Color primary = Color(0xFFE51E25);
  static const Color primaryDeep = Color(0xFFB71218);
  static const Color orange = Color(0xFFE56B1A);
  static const Color amber = Color(0xFFFFB547);
  // Festive accent used for Diwali highlights alongside the blue brand.
  static const Color diwaliGold = Color(0xFFFFC107);
  static const Color diwaliDeep = Color(0xFFB45309);

  // Surfaces (light)
  static const Color background = Color(0xFFF6F7FB);
  static const Color backgroundElevated = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardHigh = Color(0xFFF1F2F7);
  static const Color inputFill = Color(0xFFF1F2F7);

  // Glass (soft dark tints over light surface)
  static const Color glassFill = Color(0x0A0B0F1C);
  static const Color glassStroke = Color(0x14000000);
  static const Color hairline = Color(0x1A000000);

  // Text
  static const Color textPrimary = Color(0xFF0B0F1C);
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textTertiary = Color(0xFF9CA3AF);

  // Status
  static const Color stepGreen = Color(0xFF10B981);
  static const Color blue = Color(0xFF3B82F6);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color red = Color(0xFFEF4444);

  // Info banner
  static const Color infoOrangeBg = Color(0xFFFFF2E6);
  static const Color infoOrangeText = Color(0xFFB04A00);

  // Gradients
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF26066), Color(0xFFE51E25), Color(0xFFB71218)],
    stops: [0.0, 0.55, 1.0],
  );

  static const LinearGradient brandGradientSubtle = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x1FE51E25), Color(0x0FB71218)],
  );

  // Diwali festive gradient — gold → maroon. Used sparingly on festive
  // banners / badges that should sit alongside the brand blue.
  static const LinearGradient diwaliGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFFFC107), Color(0xFFE65100), Color(0xFF991B1B)],
    stops: [0.0, 0.6, 1.0],
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF1F2F7)],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFF6F7FB)],
  );

  // Emergency red gradient (big SOS / Emergency pill)
  static const LinearGradient emergencyGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFEF4444), Color(0xFFCC2A2A)],
  );
}
