import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class WordbookEmptyState extends StatelessWidget {
  final bool hasActiveQuery;
  final VoidCallback onAddFirst;

  const WordbookEmptyState({
    super.key,
    required this.hasActiveQuery,
    required this.onAddFirst,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.bookMarked,
            size: 48,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            hasActiveQuery ? '검색 결과가 없어요' : '단어장이 비어있어요',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          if (!hasActiveQuery) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onAddFirst,
              icon: const Icon(LucideIcons.plus, size: 16),
              label: const Text('첫 단어 추가하기'),
            ),
          ],
        ],
      ),
    );
  }
}
