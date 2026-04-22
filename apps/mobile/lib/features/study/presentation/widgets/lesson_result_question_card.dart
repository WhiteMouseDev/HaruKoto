import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/lesson_models.dart';

class LessonResultQuestionCard extends StatelessWidget {
  final QuestionResultModel result;
  final LessonQuestionModel question;

  const LessonResultQuestionCard({
    super.key,
    required this.result,
    required this.question,
  });

  IconData _srsTransitionIcon(String before, String after) {
    if (before == 'UNSEEN') return LucideIcons.sparkles;
    if (after == 'REVIEW' || after == 'MASTERED') return LucideIcons.trendingUp;
    if (after == 'RELEARNING') return LucideIcons.refreshCw;
    return LucideIcons.arrowLeftRight;
  }

  Color _srsTransitionColor(
    Brightness brightness,
    String before,
    String after,
  ) {
    if (after == 'MASTERED') return AppColors.success(brightness);
    if (after == 'REVIEW') return AppColors.info(brightness);
    if (after == 'LEARNING') return AppColors.warning(brightness);
    if (after == 'RELEARNING') return AppColors.error(brightness);
    if (after == 'PROVISIONAL') return AppColors.warning(brightness);
    return AppColors.lightSubtext;
  }

  String _formatReviewDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = date.difference(now);
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 후';
      if (diff.inHours < 24) return '${diff.inHours}시간 후';
      if (diff.inDays < 7) return '${diff.inDays}일 후';
      return '${date.month}/${date.day}';
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final stateBefore = result.stateBefore;
    final stateAfter = result.stateAfter;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.gap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  result.isCorrect
                      ? LucideIcons.checkCircle2
                      : LucideIcons.xCircle,
                  color: result.isCorrect
                      ? AppColors.success(brightness)
                      : AppColors.error(brightness),
                  size: AppSizes.iconMd,
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: Text(
                    question.prompt,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            if (result.explanation != null) ...[
              const SizedBox(height: AppSizes.xs),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  result.explanation!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.lightSubtext,
                  ),
                ),
              ),
            ],
            if (stateBefore != null && stateAfter != null) ...[
              const SizedBox(height: AppSizes.sm),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Row(
                  children: [
                    Icon(
                      _srsTransitionIcon(stateBefore, stateAfter),
                      size: 14,
                      color: _srsTransitionColor(
                        brightness,
                        stateBefore,
                        stateAfter,
                      ),
                    ),
                    const SizedBox(width: AppSizes.xs),
                    Text(
                      '$stateBefore → $stateAfter',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _srsTransitionColor(
                          brightness,
                          stateBefore,
                          stateAfter,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (result.isProvisionalPhase) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning(brightness)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'SRS 등록됨',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.warning(brightness),
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (result.nextReviewAt != null) ...[
              const SizedBox(height: AppSizes.xs),
              Padding(
                padding: const EdgeInsets.only(left: 28),
                child: Text(
                  '다음 복습: ${_formatReviewDate(result.nextReviewAt!)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.lightSubtext,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
