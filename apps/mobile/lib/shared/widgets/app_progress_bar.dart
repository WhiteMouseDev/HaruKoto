import 'package:flutter/material.dart';
import '../../core/theme/haru_semantic_colors.dart';
import '../../core/constants/sizes.dart';

/// Standard linear progress bar with consistent styling.
class AppProgressBar extends StatelessWidget {
  final double value;
  final double height;
  final Color? color;
  final Color? backgroundColor;

  const AppProgressBar({
    super.key,
    required this.value,
    this.height = AppSizes.progressHeight,
    this.color,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = HaruSemanticColors.of(context);
    final clampedValue = value.clamp(0.0, 1.0);
    final progressColor = color ??
        (clampedValue >= 1.0 ? semantic.success : theme.colorScheme.primary);

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: clampedValue,
        minHeight: height,
        valueColor: AlwaysStoppedAnimation(
          progressColor,
        ),
        backgroundColor: backgroundColor ?? semantic.surfaceMuted,
      ),
    );
  }
}
