import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/sizes.dart';
import '../../core/theme/haru_typography.dart';

enum HaruButtonSize { compact, regular }

abstract final class HaruButtonStyles {
  static const _compactHeight = 42.0;
  static const compactHitInset =
      (kMinInteractiveDimension - _compactHeight) / 2;

  static ButtonStyle primary(
    BuildContext context, {
    HaruButtonSize size = HaruButtonSize.compact,
  }) {
    final light = Theme.of(context).brightness == Brightness.light;
    final compact = size == HaruButtonSize.compact;
    final verticalPadding = compact ? AppSizes.sm : AppSizes.gap;

    return FilledButton.styleFrom(
      backgroundColor: light ? AppColors.brandPink : null,
      foregroundColor: light ? Colors.white : null,
      disabledBackgroundColor: light ? AppColors.redesignControl : null,
      disabledForegroundColor: light ? const Color(0xFF999999) : null,
      minimumSize: Size(0, compact ? _compactHeight : AppSizes.buttonHeight),
      tapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      // Align the visible Pretendard glyphs with the Figma capsule center.
      padding: EdgeInsets.fromLTRB(
        20,
        verticalPadding - 1,
        20,
        verticalPadding + 1,
      ),
      shape: const StadiumBorder(),
      textStyle: compact
          ? HaruTypography.krCompactButton
          : HaruTypography.krRegularButton,
    );
  }

  static ButtonStyle pillTab(
    BuildContext context, {
    required bool selected,
    required double minimumWidth,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    final selectedSurface = light ? AppColors.redesignStrong : colors.onSurface;
    final unselectedSurface =
        light ? AppColors.redesignControl : colors.surfaceContainerHigh;
    final selectedLabel = light ? Colors.white : colors.surface;
    final unselectedLabel =
        light ? AppColors.redesignForeground : colors.onSurfaceVariant;

    return TextButton.styleFrom(
      backgroundColor: selected ? selectedSurface : unselectedSurface,
      foregroundColor: selected ? selectedLabel : unselectedLabel,
      minimumSize: Size(minimumWidth, AppSizes.chipHeight),
      tapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      // Align Pretendard glyphs to the capsule's optical center.
      padding: const EdgeInsets.fromLTRB(12, 5, 12, 7),
      textStyle: HaruTypography.krPillTab,
      shape: const StadiumBorder(),
    );
  }
}
