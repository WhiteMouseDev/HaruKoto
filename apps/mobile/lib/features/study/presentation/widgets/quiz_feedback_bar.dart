import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/theme/text_theme.dart';
import '../../../../shared/widgets/haru_button_styles.dart';
import '../../data/models/quiz_question_model.dart';

class QuizFeedbackBar extends StatelessWidget {
  final QuizQuestionModel question;
  final bool isCorrect;
  final bool answered;
  final bool isLastQuestion;
  final VoidCallback onNext;

  const QuizFeedbackBar({
    super.key,
    required this.question,
    required this.isCorrect,
    required this.answered,
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
    final light = theme.brightness == Brightness.light;
    final muted = light
        ? AppColors.redesignMutedForeground
        : theme.colorScheme.onSurfaceVariant;
    final statusColor = isCorrect
        ? light
            ? AppColors.quizCorrectText
            : AppColors.quizCorrectTextDark
        : light
            ? AppColors.quizWrongText
            : AppColors.quizWrongTextDark;
    final detail = answered ? _feedbackDetail : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (detail != null) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 72),
              child: SingleChildScrollView(
                child: Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: redesignFontFamily,
                    fontSize: 12,
                    height: 1.45,
                    letterSpacing: -0.3,
                    color: muted,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (answered) ...[
            Semantics(
              liveRegion: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isCorrect ? LucideIcons.checkCircle2 : LucideIcons.xCircle,
                    size: 14,
                    color: statusColor,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      isCorrect ? '정답이에요!' : '아쉬워요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: redesignFontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        letterSpacing: -0.325,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          FilledButton(
            key: const ValueKey('quiz-next'),
            onPressed: answered ? onNext : null,
            style: HaruButtonStyles.primary(
              context,
              size: HaruButtonSize.regular,
            ),
            child: Text(
              isLastQuestion && answered ? '결과 보기' : '다음 문제',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
