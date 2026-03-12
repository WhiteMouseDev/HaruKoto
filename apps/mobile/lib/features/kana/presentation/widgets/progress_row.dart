import 'package:flutter/material.dart';

class ProgressRow extends StatelessWidget {
  final int current;
  final int total;

  const ProgressRow({super.key, required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: current / total,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHigh,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$current/$total',
          style: theme.textTheme.labelSmall?.copyWith(
            color:
                theme.colorScheme.onSurface.withValues(alpha: 0.5),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
