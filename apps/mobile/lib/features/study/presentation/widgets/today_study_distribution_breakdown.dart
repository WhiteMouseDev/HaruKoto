import 'package:flutter/material.dart';

import '../../data/models/smart_preview_model.dart';

class TodayStudyDistributionBreakdown extends StatelessWidget {
  final SessionDistribution distribution;
  final String category;

  const TodayStudyDistributionBreakdown({
    super.key,
    required this.distribution,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isGrammar = category == 'GRAMMAR';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _DistItem(
            label: isGrammar ? '새로운 문법' : '새로운 단어',
            count: distribution.newCount,
            color: theme.colorScheme.primary,
          ),
          _divider(theme),
          _DistItem(
            label: isGrammar ? '복습할 문법' : '복습할 단어',
            count: distribution.review,
            color: const Color(0xFF10B981),
          ),
          _divider(theme),
          _DistItem(
            label: isGrammar ? '재도전 문법' : '재도전 단어',
            count: distribution.retry,
            color: theme.colorScheme.error,
          ),
        ],
      ),
    );
  }

  Widget _divider(ThemeData theme) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: theme.colorScheme.outline.withValues(alpha: 0.15),
    );
  }
}

class _DistItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _DistItem({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
