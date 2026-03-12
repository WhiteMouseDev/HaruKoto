import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class QuizHeader extends StatelessWidget {
  final String title;
  final String count;
  final VoidCallback onBack;

  const QuizHeader({
    super.key,
    required this.title,
    required this.count,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child:
                const Icon(LucideIcons.arrowLeft, size: 20),
          ),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          Text(
            count,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface
                  .withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
