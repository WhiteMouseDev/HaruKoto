import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../data/models/quiz_question_model.dart';

class ClozeQuiz extends StatefulWidget {
  final List<QuizQuestionModel> questions;
  final void Function(String questionId, String selectedOptionId, bool isCorrect)
      onAnswer;
  final VoidCallback onComplete;

  const ClozeQuiz({
    super.key,
    required this.questions,
    required this.onAnswer,
    required this.onComplete,
  });

  @override
  State<ClozeQuiz> createState() => _ClozeQuizState();
}

class _ClozeQuizState extends State<ClozeQuiz> {
  int _currentIndex = 0;
  String? _selectedId;
  bool _answered = false;

  QuizQuestionModel get _question => widget.questions[_currentIndex];

  void _handleSelect(String optionId) {
    if (_answered) return;
    final isCorrect = optionId == _question.correctOptionId;
    setState(() {
      _selectedId = optionId;
      _answered = true;
    });
    widget.onAnswer(_question.questionId, optionId, isCorrect);
  }

  void _next() {
    if (_currentIndex + 1 >= widget.questions.length) {
      widget.onComplete();
      return;
    }
    setState(() {
      _currentIndex++;
      _selectedId = null;
      _answered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final sentence = _question.sentence ?? _question.questionText;
    final parts = sentence.split('{blank}');

    return Column(
      children: [
        // Progress
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (_currentIndex + 1) / widget.questions.length,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHigh,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_currentIndex + 1}/${widget.questions.length}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),

        // Sentence with blank
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      children: [
                        for (int i = 0; i < parts.length; i++) ...[
                          TextSpan(text: parts[i]),
                          if (i < parts.length - 1)
                            TextSpan(
                              text: _answered
                                  ? _question.options
                                      .firstWhere((o) =>
                                          o.id == _question.correctOptionId)
                                      .text
                                  : '____',
                              style: TextStyle(
                                color: _answered
                                    ? AppColors.success(brightness)
                                    : theme.colorScheme.primary,
                                decoration: _answered
                                    ? null
                                    : TextDecoration.underline,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  if (_question.translation != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _question.translation!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Options
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: _question.options.map((option) {
              final isSelected = _selectedId == option.id;
              final isCorrectOption =
                  option.id == _question.correctOptionId;

              Color borderColor = theme.colorScheme.outline;
              Color? bgColor;

              if (_answered) {
                if (isCorrectOption) {
                  borderColor = AppColors.success(brightness);
                  bgColor = AppColors.success(brightness).withValues(alpha: 0.1);
                } else if (isSelected) {
                  borderColor = AppColors.error(brightness);
                  bgColor = AppColors.error(brightness).withValues(alpha: 0.1);
                }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: bgColor ?? Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _answered ? null : () => _handleSelect(option.id),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor, width: 2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        option.text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Next button
        if (_answered)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _next,
                child: Text(
                  _currentIndex + 1 >= widget.questions.length
                      ? '결과 보기'
                      : '다음 문제 →',
                ),
              ),
            ),
          ),
      ],
    );
  }
}
