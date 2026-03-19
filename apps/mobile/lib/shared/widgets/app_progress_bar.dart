import 'package:flutter/material.dart';
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        valueColor: AlwaysStoppedAnimation(
          color ?? theme.colorScheme.primary,
        ),
        backgroundColor: backgroundColor ??
            theme.colorScheme.onSurface.withValues(alpha: 0.1),
      ),
    );
  }
}
