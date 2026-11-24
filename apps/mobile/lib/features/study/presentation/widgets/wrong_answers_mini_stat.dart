import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/text_theme.dart';

class WrongAnswersMiniStat extends StatelessWidget {
  const WrongAnswersMiniStat({
    super.key,
    required this.label,
    required this.value,
    this.isError = false,
  });

  final String label;
  final String value;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final secondary =
        light ? AppColors.redesignMutedForeground : colors.onSurfaceVariant;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: redesignFontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isError ? AppColors.error(theme.brightness) : foreground,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: redesignFontFamily,
                fontSize: 11,
                color: secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
