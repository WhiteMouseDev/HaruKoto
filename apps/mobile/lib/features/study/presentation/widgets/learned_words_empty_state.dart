import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class LearnedWordsEmptyState extends StatelessWidget {
  final bool hasActiveQuery;

  const LearnedWordsEmptyState({
    super.key,
    required this.hasActiveQuery,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.bookOpen,
            size: 48,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            hasActiveQuery ? '검색 결과가 없어요' : '아직 학습한 단어가 없어요',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
