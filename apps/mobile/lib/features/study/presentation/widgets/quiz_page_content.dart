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
    this.onRetryLoad,
    this.exitLabel = '학습으로 돌아가기',
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
  final VoidCallback? onRetryLoad;
  final String exitLabel;
  static const _specialModeBuilder = QuizSpecialModeBuilder();

  String get _headerTitle => session.resolvedMode == 'wrong_answer_review'
      ? '이번 퀴즈의 오답 복습'
      : session.resolvedMode == 'review'
          ? '복습'
          : '$jlptLevel ${quizType == 'VOCABULARY' ? '단어' : '문법'} 퀴즈';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (session.loading) {
      return _QuizLoadingState();
    }

    if (session.loadError != null) {
      return _QuizLoadErrorState(
        message: session.loadError!,
        onRetry: onRetryLoad,
        onExit: onExit,
        exitLabel: exitLabel,
      );
    }

    if (session.questions.isEmpty) {
      return _QuizEmptyState(
        isReviewMode: session.resolvedMode == 'review',
        onExit: onExit,
        exitLabel: exitLabel,
      );
    }

    if (session.currentQuestion == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline, size: 48),
                  const SizedBox(height: 16),
                  const Text('모든 답안이 저장됐어요'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: session.completing ? null : onComplete,
                    child:
                        Text(session.completing ? '결과를 확인하고 있어요' : '결과 확인하기'),
                  ),
                  TextButton(onPressed: onExit, child: Text(exitLabel)),
                ],
              ),
            ),
          ),
        ),
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

class _QuizLoadErrorState extends StatelessWidget {
  const _QuizLoadErrorState({
    required this.message,
    required this.onRetry,
    required this.onExit,
    required this.exitLabel,
  });

  final String message;
  final VoidCallback? onRetry;
  final VoidCallback onExit;
  final String exitLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_outlined,
                    size: 48, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text('퀴즈를 불러오지 못했어요', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                if (onRetry == null) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '퀴즈가 준비되었지만 화면을 불러오지 못했을 수 있어요. '
                    '학습으로 돌아가 이어서 학습하기를 확인해 주세요.',
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 16),
                if (onRetry != null) ...[
                  FilledButton(
                    onPressed: onRetry,
                    child: const Text('다시 불러오기'),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton(
                  onPressed: onExit,
                  child: Text(exitLabel),
                ),
              ],
            ),
          ),
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
    required this.exitLabel,
  });

  final bool isReviewMode;
  final VoidCallback onExit;
  final String exitLabel;

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
              child: Text(exitLabel),
            ),
          ],
        ),
      ),
    );
  }
}
