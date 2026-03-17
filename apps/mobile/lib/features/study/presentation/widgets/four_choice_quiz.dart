import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../shared/widgets/tts_play_button.dart';
import '../../data/models/quiz_question_model.dart';

class FourChoiceQuiz extends StatefulWidget {
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
  State<FourChoiceQuiz> createState() => _FourChoiceQuizState();
}

class _FourChoiceQuizState extends State<FourChoiceQuiz>
    with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: 8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 8, end: -8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: -4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4, end: 0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void didUpdateWidget(FourChoiceQuiz oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger shake when wrong answer is revealed
    if (widget.answered && !oldWidget.answered && !widget.isCorrect) {
      _shakeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

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
                  widget.question.questionText,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (widget.showFurigana &&
                    widget.question.questionSubText != null &&
                    widget.question.questionSubText !=
                        widget.question.questionText) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.question.questionSubText!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                TtsPlayButton(
                  vocabId: widget.question.questionId,
                ),
              ],
            ),
          ),
        ),

        // Options
        ...List.generate(widget.question.options.length, (i) {
          final option = widget.question.options[i];
          final isSelected = widget.selectedOptionId == option.id;
          final isCorrectOption =
              option.id == widget.question.correctOptionId;

          Color borderColor = theme.colorScheme.outline;
          Color? bgColor;

          if (widget.answered) {
            if (isCorrectOption) {
              borderColor = AppColors.success(brightness);
              bgColor =
                  AppColors.success(brightness).withValues(alpha: 0.1);
            } else if (isSelected && !isCorrectOption) {
              borderColor = AppColors.error(brightness);
              bgColor = AppColors.error(brightness).withValues(alpha: 0.1);
            } else {
              borderColor =
                  theme.colorScheme.outline.withValues(alpha: 0.4);
            }
          } else if (isSelected) {
            borderColor = theme.colorScheme.primary;
            bgColor =
                theme.colorScheme.primary.withValues(alpha: 0.05);
          }

          Widget tile = Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: bgColor ?? Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap:
                    widget.answered ? null : () => widget.onSelect(option.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
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

          // Wrap wrong selected option with shake animation
          if (isSelected && !isCorrectOption && widget.answered) {
            tile = AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: child,
                );
              },
              child: tile,
            );
          }

          return tile;
        }),
      ],
    );
  }
}
