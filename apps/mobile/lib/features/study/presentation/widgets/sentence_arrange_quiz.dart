import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../data/models/quiz_question_model.dart';
import 'special_quiz_flow_controller.dart';

class SentenceArrangeQuiz extends StatefulWidget {
  final List<QuizQuestionModel> questions;
  final void Function(String questionId, bool isCorrect) onAnswer;
  final VoidCallback onComplete;

  const SentenceArrangeQuiz({
    super.key,
    required this.questions,
    required this.onAnswer,
    required this.onComplete,
  });

  @override
  State<SentenceArrangeQuiz> createState() => _SentenceArrangeQuizState();
}

class _SentenceArrangeQuizState extends State<SentenceArrangeQuiz> {
  final _flow = SpecialQuizFlowController();
  List<String> _availableTokens = [];
  List<String> _selectedTokens = [];

  @override
  void initState() {
    super.initState();
    _setupQuestion();
  }

  void _setupQuestion() {
    final q = widget.questions[_flow.currentIndex];
    final tokens = q.tokens ?? [];
    _availableTokens = List.from(tokens)..shuffle(Random());
    _selectedTokens = [];
  }

  void _selectToken(String token) {
    if (_flow.answered) return;
    setState(() {
      _availableTokens.remove(token);
      _selectedTokens.add(token);
    });
  }

  void _removeToken(String token) {
    if (_flow.answered) return;
    setState(() {
      _selectedTokens.remove(token);
      _availableTokens.add(token);
    });
  }

  void _checkAnswer() {
    if (_flow.answered) return;
    final q = widget.questions[_flow.currentIndex];
    final correctOrder = q.tokens ?? [];
    final userAnswer = _selectedTokens.join();
    final isCorrect = userAnswer == correctOrder.join();

    setState(() {
      _flow.answer(isCorrect: isCorrect);
    });
    widget.onAnswer(q.questionId, isCorrect);
  }

  void _next() {
    if (_flow.isLastQuestion(widget.questions.length)) {
      widget.onComplete();
      return;
    }

    setState(() {
      _flow.advance(widget.questions.length);
      _setupQuestion();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final q = widget.questions[_flow.currentIndex];

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
                    value: _flow.progressFor(widget.questions.length),
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHigh,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(_flow.countLabelFor(widget.questions.length),
                  style: theme.textTheme.bodySmall),
            ],
          ),
        ),

        // Korean sentence
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Text(
            q.koreanSentence ?? q.questionText,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // Selected tokens area
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Answer area
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 80),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _flow.answered
                          ? (_flow.isCorrect
                              ? AppColors.success(brightness)
                              : AppColors.error(brightness))
                          : theme.colorScheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedTokens.map((token) {
                      return GestureDetector(
                        onTap: () => _removeToken(token),
                        child: _TokenChip(
                          text: token,
                          theme: theme,
                          isSelected: true,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // Available tokens
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableTokens.map((token) {
                    return GestureDetector(
                      onTap: () => _selectToken(token),
                      child: _TokenChip(
                        text: token,
                        theme: theme,
                        isSelected: false,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),

        // Actions
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: _flow.answered
                ? FilledButton(
                    onPressed: _next,
                    child: Text(
                      _flow.isLastQuestion(widget.questions.length)
                          ? '결과 보기'
                          : '다음 문제 →',
                    ))
                : FilledButton(
                    onPressed: _selectedTokens.isNotEmpty ? _checkAnswer : null,
                    child: const Text('확인'),
                  ),
          ),
        ),
      ],
    );
  }
}

class _TokenChip extends StatelessWidget {
  final String text;
  final ThemeData theme;
  final bool isSelected;

  const _TokenChip({
    required this.text,
    required this.theme,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primary.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerHigh,
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outline,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
