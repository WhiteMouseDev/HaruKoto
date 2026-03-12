import 'package:flutter/material.dart';

abstract final class AppColors {
  // Brand
  static const primary = Color(0xFFF6A5B3);
  static const brandPink = Color(0xFFFFB7C5);

  // Light theme
  static const lightBackground = Color(0xFFFCF6F5);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightSecondary = Color(0xFFFFF0F3);
  static const lightBorder = Color(0xFFFCE7EC);
  static const lightText = Color(0xFF1A1A2E);
  static const lightSubtext = Color(0xFF666680);

  // Dark theme
  static const darkBackground = Color(0xFF1A1A2E);
  static const darkCard = Color(0xFF242442);
  static const darkSecondary = Color(0xFF2A2A4A);
  static const darkBorder = Color(0x1AFFFFFF); // rgba(255,255,255,0.1)
  static const darkText = Color(0xFFFFFFFF);
  static const darkSubtext = Color(0xFFB0B0C0);

  // Semantic colors (light / dark)
  static const hkBlueLight = Color(0xFF87CEEB);
  static const hkBlueDark = Color(0xFF5BA3C9);
  static const hkYellowLight = Color(0xFFFFD93D);
  static const hkYellowDark = Color(0xFFE5C235);
  static const hkRedLight = Color(0xFFFF6B6B);
  static const hkRedDark = Color(0xFFE05252);

  static Color hkBlue(Brightness brightness) =>
      brightness == Brightness.light ? hkBlueLight : hkBlueDark;
  static Color hkYellow(Brightness brightness) =>
      brightness == Brightness.light ? hkYellowLight : hkYellowDark;
  static Color hkRed(Brightness brightness) =>
      brightness == Brightness.light ? hkRedLight : hkRedDark;

  // Semantic colors (brightness-aware)
  static Color success(Brightness brightness) =>
      brightness == Brightness.light
          ? const Color(0xFF22C55E)
          : const Color(0xFF16A34A);
  static Color error(Brightness brightness) =>
      brightness == Brightness.light
          ? const Color(0xFFEF4444)
          : const Color(0xFFDC2626);
  static Color warning(Brightness brightness) =>
      brightness == Brightness.light
          ? const Color(0xFFF59E0B)
          : const Color(0xFFD97706);
  static Color info(Brightness brightness) =>
      brightness == Brightness.light
          ? const Color(0xFF3B82F6)
          : const Color(0xFF2563EB);

  // On gradient surfaces (white text/icons on colored backgrounds)
  static const onGradient = Colors.white;
  static const onGradientMuted = Color(0xB3FFFFFF); // white70

  // Overlay colors
  static Color overlay(double alpha) => Colors.black.withValues(alpha: alpha);
}
