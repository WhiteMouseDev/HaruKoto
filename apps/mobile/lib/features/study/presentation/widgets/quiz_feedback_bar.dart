import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../data/models/quiz_question_model.dart';

class QuizFeedbackBar extends StatelessWidget {
  final QuizQuestionModel question;
  final bool isCorrect;
  final int streak;
  final bool isLastQuestion;
  final VoidCallback onNext;

  const QuizFeedbackBar({
    super.key,
    required this.question,
    required this.isCorrect,
    required this.streak,
    required this.isLastQuestion,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final scaffoldBg = theme.scaffoldBackgroundColor;

    // 정답: 브랜드 핑크 톤, 오답: error 톤
    final accentColor =
        isCorrect ? AppColors.primary : AppColors.error(brightness);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      decoration: BoxDecoration(
        color: scaffoldBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.overlay(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단 accent 라인
          Center(
            child: Container(
              width: 48,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Icon(
                isCorrect ? LucideIcons.checkCircle2 : LucideIcons.xCircle,
                size: 24,
                color: accentColor,
              ),
              const SizedBox(width: 8),
              Text(
                isCorrect
                    ? (streak >= 5
                        ? '대단해요!'
                        : streak >= 3
                            ? '연속 정답!'
                            : '정답이에요!')
                    : '아쉬워요!',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (isCorrect && streak >= 3) ...[
                const Spacer(),
                Icon(LucideIcons.flame,
                    size: 16, color: AppColors.warning(brightness)),
                const SizedBox(width: 4),
                Text(
                  '$streak',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.warning(brightness),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
          if (!isCorrect) ...[
            const SizedBox(height: 8),
            Text(
              '정답: ${question.options.firstWhere((o) => o.id == question.correctOptionId).text}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: onNext,
              child: Text(
                isLastQuestion ? '결과 보기' : '다음 문제 →',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
