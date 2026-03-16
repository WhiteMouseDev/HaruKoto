import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../data/models/quiz_question_model.dart';

class TypingQuiz extends StatefulWidget {
  final List<QuizQuestionModel> questions;
  final void Function(String questionId, bool isCorrect) onAnswer;
  final VoidCallback onComplete;

  const TypingQuiz({
    super.key,
    required this.questions,
    required this.onAnswer,
    required this.onComplete,
  });

  @override
  State<TypingQuiz> createState() => _TypingQuizState();
}

class _TypingQuizState extends State<TypingQuiz> {
  int _currentIndex = 0;
  final _controller = TextEditingController();
  bool _answered = false;
  bool _isCorrect = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  QuizQuestionModel get _question => widget.questions[_currentIndex];

  void _submit() {
    if (_answered) return;
    final userAnswer = _controller.text.trim();
    final correctAnswer = _question.answer ?? '';
    final isCorrect = userAnswer.toLowerCase() == correctAnswer.toLowerCase();

    setState(() {
      _answered = true;
      _isCorrect = isCorrect;
    });
    widget.onAnswer(_question.questionId, isCorrect);
  }

  void _next() {
    if (_currentIndex + 1 >= widget.questions.length) {
      widget.onComplete();
      return;
    }
    setState(() {
      _currentIndex++;
      _answered = false;
      _isCorrect = false;
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;

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
              Text('${_currentIndex + 1}/${widget.questions.length}',
                  style: theme.textTheme.bodySmall),
            ],
          ),
        ),

        // Prompt
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _question.prompt ?? _question.questionText,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_question.hint != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _question.hint!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Input
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _controller,
            enabled: !_answered,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
            decoration: InputDecoration(
              hintText: 'ここに入力...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: theme.colorScheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    BorderSide(color: theme.colorScheme.primary, width: 2),
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),

        // Answer feedback
        if (_answered)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isCorrect
                    ? AppColors.success(brightness).withValues(alpha: 0.1)
                    : AppColors.error(brightness).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    _isCorrect ? '정답이에요!' : '아쉬워요!',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _isCorrect
                          ? AppColors.success(brightness)
                          : AppColors.error(brightness),
                    ),
                  ),
                  if (!_isCorrect) ...[
                    const SizedBox(height: 4),
                    Text(
                      '정답: ${_question.answer}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

        // Button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: _answered
                ? FilledButton(
                    onPressed: _next,
                    child: Text(
                      _currentIndex + 1 >= widget.questions.length
                          ? '결과 보기'
                          : '다음 문제 →',
                    ),
                  )
                : FilledButton(
                    onPressed:
                        _controller.text.trim().isNotEmpty ? _submit : null,
                    child: const Text('확인'),
                  ),
          ),
        ),
      ],
    );
  }
}
