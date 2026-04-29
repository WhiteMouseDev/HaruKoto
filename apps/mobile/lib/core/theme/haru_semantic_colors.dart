import 'package:flutter/material.dart';

import '../constants/colors.dart';

@immutable
class HaruSemanticColors extends ThemeExtension<HaruSemanticColors> {
  const HaruSemanticColors({
    required this.primaryPressed,
    required this.accent,
    required this.onAccent,
    required this.accentContainer,
    required this.success,
    required this.warning,
    required this.error,
    required this.surfaceMuted,
    required this.tabActive,
    required this.tabInactive,
  });

  final Color primaryPressed;
  final Color accent;
  final Color onAccent;
  final Color accentContainer;
  final Color success;
  final Color warning;
  final Color error;
  final Color surfaceMuted;
  final Color tabActive;
  final Color tabInactive;

  static HaruSemanticColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<HaruSemanticColors>() ??
        HaruSemanticColors.fromBrightness(theme.brightness);
  }

  factory HaruSemanticColors.fromBrightness(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return HaruSemanticColors(
      primaryPressed:
          isLight ? AppColors.primaryPressed : const Color(0xFFE56F88),
      accent: isLight ? AppColors.accent : const Color(0xFFF5EDE5),
      onAccent: isLight ? AppColors.lightBackground : AppColors.darkBackground,
      accentContainer:
          isLight ? AppColors.accentContainer : AppColors.darkSecondary,
      success: AppColors.success(brightness),
      warning: AppColors.warning(brightness),
      error: AppColors.error(brightness),
      surfaceMuted:
          isLight ? AppColors.accentContainer : AppColors.darkSecondary,
      tabActive: isLight ? AppColors.accent : AppColors.darkText,
      tabInactive: isLight ? AppColors.tabInactive : AppColors.darkSubtext,
    );
  }

  @override
  HaruSemanticColors copyWith({
    Color? primaryPressed,
    Color? accent,
    Color? onAccent,
    Color? accentContainer,
    Color? success,
    Color? warning,
    Color? error,
    Color? surfaceMuted,
    Color? tabActive,
    Color? tabInactive,
  }) {
    return HaruSemanticColors(
      primaryPressed: primaryPressed ?? this.primaryPressed,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      accentContainer: accentContainer ?? this.accentContainer,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      tabActive: tabActive ?? this.tabActive,
      tabInactive: tabInactive ?? this.tabInactive,
    );
  }

  @override
  HaruSemanticColors lerp(ThemeExtension<HaruSemanticColors>? other, double t) {
    if (other is! HaruSemanticColors) return this;
    return HaruSemanticColors(
      primaryPressed: Color.lerp(primaryPressed, other.primaryPressed, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentContainer: Color.lerp(accentContainer, other.accentContainer, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      tabActive: Color.lerp(tabActive, other.tabActive, t)!,
      tabInactive: Color.lerp(tabInactive, other.tabInactive, t)!,
    );
  }
}
