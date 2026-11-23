import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/theme/text_theme.dart';
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
    final isLight = theme.brightness == Brightness.light;
    final subject = category == 'GRAMMAR' ? '문법' : '단어';
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      fontFamily: redesignFontFamily,
      color: isLight ? AppColors.redesignForeground : null,
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.gap,
        vertical: AppSizes.sm,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color:
              isLight ? AppColors.redesignOutline : theme.colorScheme.outline,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSizes.sm,
        runSpacing: AppSizes.xs,
        children: [
          Text('$jlptLevel $subject 학습 현황', style: labelStyle),
          Text(
            '${progress.studied} / ${progress.total}개',
            style: labelStyle,
          ),
        ],
      ),
    );
  }
}
