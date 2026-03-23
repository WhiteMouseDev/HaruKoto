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

  /// 피드백에 표시할 보충 정보 (정답/오답 공통)
  String? get _feedbackDetail {
    final correctText = question.options
        .where((o) => o.id == question.correctOptionId)
        .map((o) => o.text)
        .firstOrNull;

    if (isCorrect) {
      // 정답: "鳥肉 (とりにく) — 닭고기"
      final word = question.questionText;
      final reading = question.questionSubText;
      final meaning = question.meaningKo;
      if (meaning != null && meaning.isNotEmpty) {
        final readingPart =
            (reading != null && reading.isNotEmpty) ? ' ($reading)' : '';
        return '$word$readingPart — $meaning';
      }
      // explanation이 있으면 (cloze, arrange)
      if (question.explanation != null && question.explanation!.isNotEmpty) {
        return question.explanation;
      }
      return null;
    } else {
      // 오답: "정답: 닭고기"  + 원어 보충 + explanation
      final word = question.questionText;
      final reading = question.questionSubText;
      final meaning = question.meaningKo;
      final parts = <String>[];

      if (meaning != null && meaning.isNotEmpty) {
        final readingPart =
            (reading != null && reading.isNotEmpty) ? ' ($reading)' : '';
        parts.add('정답: ${correctText ?? meaning}  ·  $word$readingPart');
      } else if (correctText != null) {
        parts.add('정답: $correctText');
      }

      // Show explanation for additional learning context
      if (question.explanation != null && question.explanation!.isNotEmpty) {
        parts.add(question.explanation!);
      }

      return parts.isNotEmpty ? parts.join('\n') : null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isLight = brightness == Brightness.light;

    // 듀오링고 스타일: 정답/오답 시맨틱 컬러
    final bgColor = isCorrect
        ? (isLight ? AppColors.quizCorrectBg : AppColors.quizCorrectBgDark)
        : (isLight ? AppColors.quizWrongBg : AppColors.quizWrongBgDark);

    final accentColor = isCorrect
        ? (isLight ? AppColors.quizCorrectText : AppColors.quizCorrectTextDark)
        : (isLight ? AppColors.quizWrongText : AppColors.quizWrongTextDark);

    final buttonColor = isCorrect
        ? (isLight
            ? AppColors.quizCorrectButton
            : AppColors.quizCorrectButtonDark)
        : (isLight ? AppColors.quizWrongButton : AppColors.quizWrongButtonDark);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      decoration: BoxDecoration(
        color: bgColor,
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
                color: accentColor.withValues(alpha: 0.3),
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
                  color: accentColor,
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
          // 보충 정보: 정답이든 오답이든 학습 강화용 한 줄 표시
          if (_feedbackDetail != null) ...[
            const SizedBox(height: 8),
            Text(
              _feedbackDetail!,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: accentColor.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: onNext,
              style: FilledButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isLastQuestion ? '결과 보기' : '다음 문제 →',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
