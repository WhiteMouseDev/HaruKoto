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
}
