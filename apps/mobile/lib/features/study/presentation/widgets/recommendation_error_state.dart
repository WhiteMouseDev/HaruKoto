import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class RecommendationErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const RecommendationErrorState({
    super.key,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        children: [
          const SizedBox(height: 32),
          Text(
            '추천을 불러올 수 없습니다',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            label: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}
