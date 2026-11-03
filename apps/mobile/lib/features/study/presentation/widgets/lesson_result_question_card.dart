import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/lesson_models.dart';
import 'lesson_result_feedback.dart';

class LessonResultQuestionCard extends StatelessWidget {
  final QuestionResultModel result;
  final LessonQuestionModel? question;

  const LessonResultQuestionCard({
    super.key,
    required this.result,
    required this.question,
  });

  String? _stateLabel(String? state) {
    switch (state?.trim().toUpperCase()) {
      case 'UNSEEN':
        return '새로 배우기 시작했어요';
      case 'PROVISIONAL':
        return '복습을 준비하고 있어요';
      case 'LEARNING':
        return '학습 중';
      case 'REVIEW':
        return '복습 예정';
      case 'RELEARNING':
        return '다시 익히는 중';
      case 'MASTERED':
        return '익힌 항목';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final matchingQuestion = question?.order == result.order ? question : null;
    final answer = lessonResultAnswerText(result, matchingQuestion);
    final prompt = matchingQuestion?.prompt.trim();
    final explanation = result.explanation?.trim();
    final reviewDate = lessonResultReviewDate(result.nextReviewAt);
    final stateLabel = _stateLabel(result.stateAfter);
    final isSentence = matchingQuestion?.type == 'SENTENCE_REORDER';
    final answerSurface = brightness == Brightness.light
        ? AppColors.sakuraTrack
        : AppColors.primary.withValues(alpha: 0.12);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.gap),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                    '${result.order > 0 ? '문제 ${result.order} · ' : ''}'
                    '${result.isCorrect ? '정답이에요' : '다시 확인해요'}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              prompt == null || prompt.isEmpty
                  ? '이 문항의 원문을 확인할 수 없어요.'
                  : prompt,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSizes.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: BoxDecoration(
                color: answerSurface,
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isSentence ? '완성 문장' : '정답',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    answer ?? '정답 정보를 확인할 수 없어요.',
                    style: answer == null
                        ? theme.textTheme.bodySmall
                        : theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              '해설',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              explanation == null || explanation.isEmpty
                  ? '이 문항에는 별도 해설이 없어요.'
                  : explanation,
              style: theme.textTheme.bodyMedium,
            ),
            if (stateLabel != null || reviewDate != null) ...[
              const SizedBox(height: AppSizes.sm),
              Divider(color: theme.colorScheme.outlineVariant),
              if (stateLabel != null)
                Text(
                  '제출 당시 상태: $stateLabel',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (reviewDate != null) ...[
                const SizedBox(height: AppSizes.xs),
                Text(
                  '제출 당시 복습 예정: $reviewDate',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
