import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

TextTheme appTextTheme(Brightness brightness) {
  final base = GoogleFonts.notoSansJpTextTheme();
  final color = brightness == Brightness.light
      ? const Color(0xFF1A1A2E)
      : const Color(0xFFFFFFFF);

  return base.copyWith(
    displayLarge: base.displayLarge?.copyWith(color: color, fontWeight: FontWeight.w700),
    displayMedium: base.displayMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
    displaySmall: base.displaySmall?.copyWith(color: color, fontWeight: FontWeight.w700),
    headlineLarge: base.headlineLarge?.copyWith(color: color, fontWeight: FontWeight.w600),
    headlineMedium: base.headlineMedium?.copyWith(color: color, fontWeight: FontWeight.w600),
    headlineSmall: base.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
    titleLarge: base.titleLarge?.copyWith(color: color, fontWeight: FontWeight.w600),
    titleMedium: base.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w500),
    titleSmall: base.titleSmall?.copyWith(color: color, fontWeight: FontWeight.w500),
    bodyLarge: base.bodyLarge?.copyWith(color: color, fontWeight: FontWeight.w400),
    bodyMedium: base.bodyMedium?.copyWith(color: color, fontWeight: FontWeight.w400),
    bodySmall: base.bodySmall?.copyWith(color: color, fontWeight: FontWeight.w400),
    labelLarge: base.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w500),
    labelMedium: base.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w500),
    labelSmall: base.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w500),
  );
}
