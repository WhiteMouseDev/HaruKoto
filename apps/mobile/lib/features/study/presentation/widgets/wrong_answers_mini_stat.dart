import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';

class WrongAnswersMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final bool isError;

  const WrongAnswersMiniStat({
    super.key,
    required this.label,
    required this.value,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isError
                    ? AppColors.error(theme.brightness)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
