import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../data/models/quiz_question_model.dart';

class FourChoiceQuiz extends StatelessWidget {
  final QuizQuestionModel question;
  final String? selectedOptionId;
  final bool answered;
  final bool isCorrect;
  final bool showFurigana;
  final ValueChanged<String> onSelect;

  const FourChoiceQuiz({
    super.key,
    required this.question,
    this.selectedOptionId,
    this.answered = false,
    this.isCorrect = false,
    this.showFurigana = true,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return Column(
      children: [
        // Question
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  question.questionText,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (showFurigana &&
                    question.questionSubText != null &&
                    question.questionSubText != question.questionText) ...[
                  const SizedBox(height: 8),
                  Text(
                    question.questionSubText!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Icon(
                  LucideIcons.volume2,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),

        // Options
        ...List.generate(question.options.length, (i) {
          final option = question.options[i];
          final isSelected = selectedOptionId == option.id;
          final isCorrectOption = option.id == question.correctOptionId;

          Color borderColor = theme.colorScheme.outline;
          Color? bgColor;

          if (answered) {
            if (isCorrectOption) {
              borderColor = AppColors.success(brightness);
              bgColor = AppColors.success(brightness).withValues(alpha: 0.1);
            } else if (isSelected && !isCorrectOption) {
              borderColor = AppColors.error(brightness);
              bgColor = AppColors.error(brightness).withValues(alpha: 0.1);
            } else {
              borderColor = theme.colorScheme.outline.withValues(alpha: 0.4);
            }
          } else if (isSelected) {
            borderColor = theme.colorScheme.primary;
            bgColor = theme.colorScheme.primary.withValues(alpha: 0.05);
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: bgColor ?? Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: answered ? null : () => onSelect(option.id),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          option.text,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
