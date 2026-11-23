import 'package:flutter/material.dart';

import '../../../../core/constants/sizes.dart';
import '../../data/models/smart_preview_model.dart';

class TodayStudyProgressSummary extends StatelessWidget {
  final OverallProgress progress;
  final String jlptLevel;
  final String category;

  const TodayStudyProgressSummary({
    super.key,
    required this.progress,
    required this.jlptLevel,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subject = category == 'GRAMMAR' ? '문법' : '단어';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.gap,
        vertical: AppSizes.sm,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSizes.sm,
        runSpacing: AppSizes.xs,
        children: [
          Text('$jlptLevel $subject 학습 현황', style: theme.textTheme.bodySmall),
          Text(
            '${progress.studied} / ${progress.total}개',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
