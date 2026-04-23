import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/quiz_settings_provider.dart';
import '../../providers/quiz_session_provider.dart';
import 'quiz_special_mode_builder.dart';
import 'quiz_special_mode_content.dart';
import 'quiz_standard_mode_content.dart';

export 'quiz_special_mode_builder.dart' show QuizSpecialAnswerHandler;

class QuizPageContent extends ConsumerWidget {
  const QuizPageContent({
    super.key,
    required this.session,
    required this.quizType,
    required this.jlptLevel,
    required this.onBackRequested,
    required this.onExit,
    required this.onAnswer,
    required this.onNext,
    required this.onComplete,
    required this.onSubmitSpecialAnswer,
  });

  final QuizSessionState session;
  final String quizType;
  final String jlptLevel;
  final VoidCallback onBackRequested;
  final VoidCallback onExit;
  final VoidCallback onNext;
  final VoidCallback onComplete;
  final ValueChanged<String> onAnswer;
  final QuizSpecialAnswerHandler onSubmitSpecialAnswer;
  static const _specialModeBuilder = QuizSpecialModeBuilder();

  String get _headerTitle => session.resolvedMode == 'review'
      ? '오답 복습'
      : '$jlptLevel ${quizType == 'VOCABULARY' ? '단어' : '문법'} 퀴즈';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (session.loading) {
      return _QuizLoadingState();
    }

    if (session.questions.isEmpty) {
      return _QuizEmptyState(
        isReviewMode: session.resolvedMode == 'review',
        onExit: onExit,
      );
    }

    final showFurigana = ref.watch(quizSettingsProvider).showFurigana;
    final specialModeChild = _specialModeBuilder.build(
      resolvedMode: session.resolvedMode ?? '',
      questions: session.unansweredQuestions,
      quizType: quizType,
      showFurigana: showFurigana,
      onComplete: onComplete,
      onSubmitSpecialAnswer: onSubmitSpecialAnswer,
    );
    if (specialModeChild != null) {
      return QuizSpecialModeContent(
        title: _headerTitle,
        count: session.headerCount,
        onBack: onBackRequested,
        child: specialModeChild,
      );
    }

    final question = session.currentQuestion!;
    return QuizStandardModeContent(
      title: _headerTitle,
      count: session.headerCount,
      question: question,
      progress: session.progress,
      streak: session.streak,
      selectedOptionId: session.selectedOptionId,
      answered: session.answered,
      isCorrect: session.isCorrect,
      isLastQuestion: session.isLastQuestion,
      showFurigana: showFurigana,
      onBack: onBackRequested,
      onAnswer: onAnswer,
      onNext: onNext,
    );
  }
}

class _QuizLoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              '퀴즈를 준비하고 있어요...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizEmptyState extends StatelessWidget {
  const _QuizEmptyState({
    required this.isReviewMode,
    required this.onExit,
  });

  final bool isReviewMode;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isReviewMode ? Icons.celebration : Icons.sentiment_dissatisfied,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              isReviewMode ? '복습할 문제가 없어요!' : '이 레벨의 콘텐츠를 준비하고 있어요',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onExit,
              child: const Text('학습으로 돌아가기'),
            ),
          ],
        ),
      ),
    );
  }
}
