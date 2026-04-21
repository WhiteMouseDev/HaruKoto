import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/lesson_models.dart';

class LessonVocabPreviewChip extends StatelessWidget {
  final VocabItemModel vocab;

  const LessonVocabPreviewChip({
    super.key,
    required this.vocab,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showReading = vocab.word != vocab.reading;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.lightCard,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            vocab.word,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.lightText,
            ),
          ),
          if (showReading)
            Text(
              vocab.reading,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.lightSubtext,
                fontSize: 10,
              ),
            ),
          Text(
            vocab.meaningKo,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.primaryStrong,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
