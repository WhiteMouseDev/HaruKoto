import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/lesson_models.dart';

class LessonVocabPreviewChip extends StatelessWidget {
  static const double width = 116;
  static const double height = 84;
  static const double _readingSlotHeight = 14;
  static const double _compactReadingSpacerHeight = 8;

  final VocabItemModel vocab;

  const LessonVocabPreviewChip({
    super.key,
    required this.vocab,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showReading = vocab.word != vocab.reading;

    return SizedBox(
      width: width,
      height: height,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 24,
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  vocab.word,
                  maxLines: 1,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.lightText,
                  ),
                ),
              ),
            ),
            SizedBox(height: showReading ? 2 : 4),
            SizedBox(
              height: showReading
                  ? _readingSlotHeight
                  : _compactReadingSpacerHeight,
              child: showReading
                  ? Text(
                      vocab.reading,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.lightSubtext,
                        fontSize: 10,
                        height: 1.1,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 18,
              width: double.infinity,
              child: Text(
                vocab.meaningKo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.primaryStrong,
                  fontSize: 11,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LessonVocabPreviewMoreChip extends StatelessWidget {
  final int remainingCount;
  final int totalCount;
  final VoidCallback onTap;

  const LessonVocabPreviewMoreChip({
    super.key,
    required this.remainingCount,
    required this.totalCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 76,
      height: LessonVocabPreviewChip.height,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.lightSecondary,
            borderRadius: BorderRadius.circular(AppSizes.radiusSm),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$remainingCount개',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.primaryStrong,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '더 보기',
                maxLines: 1,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.lightSubtext,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '총 $totalCount개',
                maxLines: 1,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.lightSubtext,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LessonVocabSheetRow extends StatelessWidget {
  final VocabItemModel vocab;

  const LessonVocabSheetRow({
    super.key,
    required this.vocab,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showReading = vocab.word != vocab.reading;

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: AppColors.lightCard,
        borderRadius: BorderRadius.circular(AppSizes.radiusSm),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vocab.word,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.lightText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(
                  height: 18,
                  child: showReading
                      ? Text(
                          vocab.reading,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.lightSubtext,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                vocab.meaningKo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.primaryStrong,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LessonVocabCountPill extends StatelessWidget {
  final int count;

  const LessonVocabCountPill({
    super.key,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      ),
      child: Text(
        '총 $count개',
        style: theme.textTheme.labelSmall?.copyWith(
          color: AppColors.primaryStrong,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
