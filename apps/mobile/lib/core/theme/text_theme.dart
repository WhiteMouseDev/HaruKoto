import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';

TextTheme appTextTheme(Brightness brightness) {
  final base = GoogleFonts.notoSansKrTextTheme();
  final jpFontFamily = GoogleFonts.notoSansJp().fontFamily;
  final fallback = [if (jpFontFamily != null) jpFontFamily];
  final color =
      brightness == Brightness.light ? AppColors.lightText : AppColors.darkText;

  return base.copyWith(
    displayLarge: base.displayLarge?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
        fontFamilyFallback: fallback),
    displayMedium: base.displayMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
        fontFamilyFallback: fallback),
    displaySmall: base.displaySmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w700,
        fontFamilyFallback: fallback),
    headlineLarge: base.headlineLarge?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
        fontFamilyFallback: fallback),
    headlineMedium: base.headlineMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
        fontFamilyFallback: fallback),
    headlineSmall: base.headlineSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
        fontFamilyFallback: fallback),
    titleLarge: base.titleLarge?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
        fontFamilyFallback: fallback),
    titleMedium: base.titleMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w500,
        fontFamilyFallback: fallback),
    titleSmall: base.titleSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w500,
        fontFamilyFallback: fallback),
    bodyLarge: base.bodyLarge?.copyWith(
        color: color,
        fontWeight: FontWeight.w400,
        fontFamilyFallback: fallback),
    bodyMedium: base.bodyMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w400,
        fontFamilyFallback: fallback),
    bodySmall: base.bodySmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w400,
        fontFamilyFallback: fallback),
    labelLarge: base.labelLarge?.copyWith(
        color: color,
        fontWeight: FontWeight.w500,
        fontFamilyFallback: fallback),
    labelMedium: base.labelMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w500,
        fontFamilyFallback: fallback),
    labelSmall: base.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w500,
        fontFamilyFallback: fallback),
  );
}
