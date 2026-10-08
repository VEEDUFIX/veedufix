import 'package:flutter/material.dart';

/// Semantic design tokens shared by customer, Partner, and Admin surfaces.
///
/// Keep visual decisions here so a brand adjustment stays consistent across
/// all Flutter apps. Feature code should prefer these tokens or themed shared
/// components over one-off values.
abstract final class VeeduFixDesignSystem {
  static const Color gold = Color(0xFFC2A15E);
  static const Color ivory = Color(0xFFF9F5EC);
  static const Color surface = Color(0xFFFFFDF9);
  static const Color ink = Color(0xFF13110F);
  static const Color mutedInk = Color(0xFF6B6256);
  static const Color border = Color(0xFFE5D8C6);
  static const Color success = Color(0xFF2D7A57);
  static const Color warning = Color(0xFFAA7C2F);
  static const Color error = Color(0xFFB34B43);

  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space28 = 28;
  static const double space32 = 32;
  static const double space40 = 40;
  static const double space48 = 48;
  static const double space56 = 56;

  static const double radiusSmall = 12;
  static const double radiusMedium = 16;
  static const double radiusLarge = 20;
  static const double radiusHero = 20;
  static const double buttonHeight = 54;
  static const double inputHeight = 54;
  static const double pageMargin = 16;
  static const double minimumTouchTarget = 44;

  static const Duration motionFast = Duration(milliseconds: 180);
  static const Duration motionStandard = Duration(milliseconds: 220);
}
