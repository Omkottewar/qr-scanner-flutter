import 'package:flutter/widgets.dart';

/// Shared spacing values, so every screen lines up the same way.
///
/// Use [page] for the left/right inset of screen content, so content edges
/// don't jump when switching tabs. Gaps follow a 4/8 scale.
abstract final class AppSpacing {
  /// Left/right inset for screen content on every tab and full screen.
  static const double page = 20;

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Extra scroll room at the bottom of tab content, on top of the
  /// bottom-nav inset that SafeArea / MediaQuery padding already adds.
  static const double tabBottom = 24;

  static const EdgeInsets pageH = EdgeInsets.symmetric(horizontal: page);
}

/// Shared corner radii. Matches the theme: inputs 14, buttons 16,
/// cards 20, dialogs 22.
abstract final class AppRadius {
  static const double xs = 4;   // tags, tiny chips
  static const double sm = 12;  // small cards / tiles
  static const double md = 16;  // buttons, list cards
  static const double lg = 20;  // cards
  static const double xl = 22;  // dialogs, hero cards
  static const double pill = 999;
}
