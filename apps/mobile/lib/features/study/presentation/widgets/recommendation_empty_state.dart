import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class RecommendationEmptyState extends StatelessWidget {
  const RecommendationEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(
              LucideIcons.flower2,
              size: 32,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              '추천 학습이 없어요',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '자율 탭에서 원하는 학습을 시작해보세요',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
