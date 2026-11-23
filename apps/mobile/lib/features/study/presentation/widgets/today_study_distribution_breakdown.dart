import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
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
    final subject = category == 'GRAMMAR' ? '문법' : '단어';

    return Container(
      padding: const EdgeInsets.all(AppSizes.gap),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DistItem(
            label: '새로운 $subject',
            count: distribution.newCount,
            color: theme.brightness == Brightness.dark
                ? theme.colorScheme.primary
                : AppColors.primaryButton,
          ),
          const SizedBox(width: AppSizes.sm),
          _DistItem(
            label: '복습할 $subject',
            count: distribution.review,
          ),
          const SizedBox(width: AppSizes.sm),
          _DistItem(
            label: '재도전 $subject',
            count: distribution.retry,
          ),
        ],
      ),
    );
  }
}

class _DistItem extends StatelessWidget {
  final String label;
  final int count;
  final Color? color;

  const _DistItem({
    required this.label,
    required this.count,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Text(
            '$count개',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
