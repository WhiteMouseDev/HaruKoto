import 'package:flutter/material.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/kana_stage_model.dart';

class StageQuiz extends StatelessWidget {
  final QuizQuestion? question;
  final int currentIndex;
  final int totalCount;
  final String? selectedOption;
  final bool showFeedback;
  final ValueChanged<String> onSelect;

  const StageQuiz({
    super.key,
    required this.question,
    required this.currentIndex,
    required this.totalCount,
    required this.selectedOption,
    required this.showFeedback,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (question == null) return const SizedBox.shrink();
    final current = question!;
    final theme = Theme.of(context);
    final progressPct = totalCount > 0
        ? (currentIndex / totalCount * 100).round()
        : 0;
    final isKanaText =
        RegExp(r'^[\u3040-\u309F\u30A0-\u30FF]$')
            .hasMatch(current.questionText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '문제 풀기',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
            Text(
              '${currentIndex + 1}/$totalCount',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progressPct / 100,
            minHeight: 6,
            backgroundColor: theme.colorScheme.surfaceContainerHigh,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: AppSizes.xl),
        Center(
          child: Column(
            children: [
              Text(
                current.questionText,
                style: TextStyle(
                  fontSize: isKanaText ? 52 : 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (current.questionSubText != null) ...[
                const SizedBox(height: 8),
                Text(
                  current.questionSubText!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface
                        .withValues(alpha: 0.5),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSizes.xl),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: current.options.map((option) {
            final isSelected = selectedOption == option.id;
            final isCorrect =
                option.id == current.correctOptionId;

            Color bgColor = theme.colorScheme.surface;
            Color borderColor = theme.colorScheme.outline
                .withValues(alpha: 0.3);
            Color textColor = theme.colorScheme.onSurface;

            if (showFeedback) {
              if (isCorrect) {
                bgColor = const Color(0xFF4CAF50)
                    .withValues(alpha: 0.1);
                borderColor = const Color(0xFF4CAF50);
                textColor = const Color(0xFF4CAF50);
              } else if (isSelected && !isCorrect) {
                bgColor = theme.colorScheme.error
                    .withValues(alpha: 0.1);
                borderColor = theme.colorScheme.error;
                textColor = theme.colorScheme.error;
              } else {
                bgColor = theme.colorScheme.surface
                    .withValues(alpha: 0.5);
              }
            }

            return SizedBox(
              width:
                  (MediaQuery.of(context).size.width - 60) / 2,
              child: Material(
                color: bgColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: borderColor),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: showFeedback
                      ? null
                      : () => onSelect(option.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 16),
                    child: Center(
                      child: Text(
                        option.text,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
