import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/text_theme.dart';

class WrongAnswersMiniStat extends StatelessWidget {
  const WrongAnswersMiniStat({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    this.isError = false,
  });

  final String label;
  final int value;
  final String unit;
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
            Text.rich(
              TextSpan(
                text: '$value',
                style: TextStyle(
                  color: isError
                      ? (light ? const Color(0xFFD32F2F) : colors.error)
                      : foreground,
                ),
                children: [
                  TextSpan(
                    text: unit,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: redesignFontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: redesignFontFamily,
                fontSize: 11,
                height: 1.5,
                color: secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
