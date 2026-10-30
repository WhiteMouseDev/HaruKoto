import 'package:flutter/material.dart';

import '../../../core/constants/colors.dart';

/// Warm neutral surfaces keep brand accents focused on learning actions.
abstract final class StudyMapColors {
  /// The route color identifies the curriculum; it never represents progress.
  static const route = AppColors.primary;

  static Color accent(Brightness brightness) => brightness == Brightness.light
      ? AppColors.sakuraOn
      : AppColors.sakuraContainer;

  static Color marker(Brightness brightness) => brightness == Brightness.light
      ? AppColors.primary
      : Color.lerp(AppColors.primary, AppColors.sakuraContainer, 0.25)!;

  static Color icon(Brightness brightness) => marker(brightness);

  static Color button(Brightness brightness) => brightness == Brightness.light
      ? AppColors.sakuraContainer
      : Color.alphaBlend(
          AppColors.primary.withValues(alpha: 0.22),
          AppColors.darkCard,
        );

  static Color onButton(Brightness brightness) => accent(brightness);

  static Color track(Brightness brightness) => brightness == Brightness.light
      ? AppColors.lightBorderStrong
      : Color.alphaBlend(
          AppColors.darkBorder,
          AppColors.darkCard,
        );

  static Color panel(Brightness brightness) => brightness == Brightness.light
      ? AppColors.surfaceMuted
      : AppColors.darkSecondary;

  static Color trainDetail(Brightness brightness) =>
      brightness == Brightness.light
          ? AppColors.sakuraOn
          : AppColors.darkBackground;

  static Color trainLight(Brightness brightness) =>
      brightness == Brightness.light ? Colors.white : AppColors.darkBackground;
}
