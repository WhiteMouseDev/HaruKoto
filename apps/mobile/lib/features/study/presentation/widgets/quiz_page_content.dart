import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/quiz_settings_provider.dart';
import '../../providers/quiz_session_provider.dart';
import 'four_choice_quiz.dart';
import 'quiz_feedback_bar.dart';
import 'quiz_header.dart';
import 'quiz_progress_bar.dart';
import 'quiz_special_mode_builder.dart';

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
      return _QuizSpecialModeScaffold(
        title: _headerTitle,
        count: session.headerCount,
        onBack: onBackRequested,
        child: specialModeChild,
      );
    }

    final question = session.currentQuestion!;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                QuizHeader(
                  title: _headerTitle,
                  count: session.headerCount,
                  onBack: onBackRequested,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: QuizProgressBar(
                    progress: session.progress,
                    streak: session.streak,
                    showStreak: session.answered,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FourChoiceQuiz(
                      question: question,
                      selectedOptionId: session.selectedOptionId,
                      answered: session.answered,
                      isCorrect: session.isCorrect,
                      showFurigana: showFurigana,
                      onSelect: onAnswer,
                    ),
                  ),
                ),
              ],
            ),
            if (session.answered)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: QuizFeedbackBar(
                  question: question,
                  isCorrect: session.isCorrect,
                  streak: session.streak,
                  isLastQuestion: session.isLastQuestion,
                  onNext: onNext,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuizSpecialModeScaffold extends StatelessWidget {
  const _QuizSpecialModeScaffold({
    required this.title,
    required this.count,
    required this.onBack,
    required this.child,
  });

  final String title;
  final String count;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            QuizHeader(
              title: title,
              count: count,
              onBack: onBack,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: child,
              ),
            ),
          ],
        ),
      ),
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
