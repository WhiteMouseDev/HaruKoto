import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/sound_service.dart';
import '../../../core/providers/quiz_settings_provider.dart';
import '../providers/quiz_session_provider.dart';
import 'quiz_result_page.dart';
import 'widgets/four_choice_quiz.dart';
import 'widgets/matching_quiz.dart';
import 'widgets/cloze_quiz.dart';
import 'widgets/sentence_arrange_quiz.dart';
import 'widgets/typing_quiz.dart';
import 'widgets/quiz_progress_bar.dart';
import 'widgets/quiz_header.dart';
import 'widgets/quiz_feedback_bar.dart';

/// No-transition route for quiz pages (avoids distracting slide animation).
Route<T> quizRoute<T>(Widget child) => PageRouteBuilder<T>(
      pageBuilder: (_, __, ___) => child,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );

class QuizPage extends ConsumerStatefulWidget {
  final String quizType;
  final String jlptLevel;
  final int count;
  final String? mode;
  final String? resumeSessionId;
  final String? stageId;

  const QuizPage({
    super.key,
    this.quizType = 'VOCABULARY',
    this.jlptLevel = 'N5',
    this.count = 10,
    this.mode,
    this.resumeSessionId,
    this.stageId,
  });

  @override
  ConsumerState<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends ConsumerState<QuizPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    Future(_initializeQuiz);
  }

  @override
  void dispose() {
    _timer?.cancel();
    final container = ProviderScope.containerOf(context, listen: false);
    Future(() => container.invalidate(quizSessionProvider));
    super.dispose();
  }

  Future<void> _initializeQuiz() async {
    await ref.read(quizSessionProvider.notifier).initialize(
          QuizSessionRequest(
            quizType: widget.quizType,
            jlptLevel: widget.jlptLevel,
            count: widget.count,
            mode: widget.mode,
            resumeSessionId: widget.resumeSessionId,
            stageId: widget.stageId,
          ),
        );
    if (!mounted) return;
    _restartTimerIfNeeded();
  }

  void _restartTimerIfNeeded() {
    _timer?.cancel();
    final session = ref.read(quizSessionProvider);
    if (session.loading ||
        session.questions.isEmpty ||
        session.answered ||
        session.isSpecialMode) {
      return;
    }
    ref.read(quizSessionProvider.notifier).resetTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      ref.read(quizSessionProvider.notifier).incrementTimer();
    });
  }

  Future<void> _handleAnswer(String optionId) async {
    _timer?.cancel();
    final session = ref.read(quizSessionProvider);
    final isCorrect =
        ref.read(quizSessionProvider.notifier).answerCurrentQuestion(
              optionId: optionId,
              questionType: session.effectiveQuizType(widget.quizType),
            );
    if (isCorrect == null) return;
    final streak = ref.read(quizSessionProvider).streak;

    // Haptic + sound feedback (fire-and-forget)
    final haptic = HapticService();
    final sound = SoundService();
    if (isCorrect) {
      unawaited(streak >= 3 ? haptic.heavy() : haptic.medium());
      unawaited(sound.play(streak >= 3 ? SoundType.combo : SoundType.correct));
    } else {
      unawaited(haptic.heavy());
      unawaited(sound.play(SoundType.wrong));
    }
  }

  Future<void> _handleNext() async {
    final session = ref.read(quizSessionProvider);
    if (session.isLastQuestion) {
      await _completeQuiz();
      return;
    }

    ref.read(quizSessionProvider.notifier).advanceToNextQuestion();
    _restartTimerIfNeeded();
  }

  Future<void> _completeQuiz() async {
    _timer?.cancel();
    try {
      final result = await ref.read(quizSessionProvider.notifier).completeQuiz(
            stageId: widget.stageId,
          );
      if (result == null || !mounted) return;
      final latestSession = ref.read(quizSessionProvider);
      if (!mounted) return;
      unawaited(HapticService().heavy());
      unawaited(SoundService().play(SoundType.complete));
      unawaited(Navigator.of(context, rootNavigator: true).pushReplacement(
        quizRoute(QuizResultPage(
          result: result,
          quizType: latestSession.displayQuizType(widget.quizType),
          jlptLevel: widget.jlptLevel,
          sessionId: latestSession.sessionId!,
        )),
      ));
    } catch (e) {
      debugPrint('Failed to complete quiz: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('퀴즈 결과 저장에 실패했어요.')),
        );
      }
    }
  }

  Future<bool> _onWillPop() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('퀴즈를 종료할까요?'),
        content: const Text('진행 상황은 저장돼요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('종료'),
          ),
        ],
      ),
    );
    return shouldPop ?? false;
  }

  String _headerTitle(QuizSessionState session) => session.resolvedMode ==
          'review'
      ? '오답 복습'
      : '${widget.jlptLevel} ${widget.quizType == 'VOCABULARY' ? '단어' : '문법'} 퀴즈';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = ref.watch(quizSessionProvider);

    if (session.loading) {
      return _buildLoadingState(theme);
    }

    if (session.questions.isEmpty) {
      return _buildEmptyState(theme);
    }

    final unanswered = session.unansweredQuestions;

    if (session.resolvedMode == 'matching') {
      final showFurigana = ref.watch(quizSettingsProvider).showFurigana;
      return _buildSpecialMode(
        MatchingQuiz(
          questions: unanswered,
          showFurigana: showFurigana,
          onMatchResult: (qId, isCorrect) {
            _submitSpecialAnswer(qId, isCorrect, widget.quizType);
          },
          onComplete: _completeQuiz,
        ),
      );
    }

    if (session.resolvedMode == 'cloze') {
      return _buildSpecialMode(
        ClozeQuiz(
          questions: unanswered,
          onAnswer: (qId, optionId, isCorrect) {
            _submitSpecialAnswer(qId, isCorrect, 'CLOZE', optionId: optionId);
          },
          onComplete: _completeQuiz,
        ),
      );
    }

    if (session.resolvedMode == 'arrange') {
      return _buildSpecialMode(
        SentenceArrangeQuiz(
          questions: unanswered,
          onAnswer: (qId, isCorrect) {
            _submitSpecialAnswer(qId, isCorrect, 'SENTENCE_ARRANGE');
          },
          onComplete: _completeQuiz,
        ),
      );
    }

    if (session.resolvedMode == 'typing') {
      return _buildSpecialMode(
        TypingQuiz(
          questions: unanswered,
          onAnswer: (qId, isCorrect) {
            _submitSpecialAnswer(qId, isCorrect, 'VOCABULARY');
          },
          onComplete: _completeQuiz,
        ),
      );
    }

    return _buildDefaultQuiz(theme, session);
  }

  void _submitSpecialAnswer(
    String qId,
    bool isCorrect,
    String questionType, {
    String? optionId,
  }) {
    ref.read(quizSessionProvider.notifier).submitSpecialAnswer(
          questionId: qId,
          isCorrect: isCorrect,
          questionType: questionType,
          optionId: optionId,
        );
  }

  Widget _buildPopScope({required Widget child}) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: child,
    );
  }

  Widget _buildSpecialMode(Widget quizWidget) {
    final session = ref.read(quizSessionProvider);
    return _buildPopScope(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              QuizHeader(
                title: _headerTitle(session),
                count: session.headerCount,
                onBack: () async {
                  final shouldPop = await _onWillPop();
                  if (shouldPop && mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: quizWidget,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme) {
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

  Widget _buildEmptyState(ThemeData theme) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ref.watch(quizSessionProvider).resolvedMode == 'review'
                  ? Icons.celebration
                  : Icons.sentiment_dissatisfied,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              ref.watch(quizSessionProvider).resolvedMode == 'review'
                  ? '복습할 문제가 없어요!'
                  : '이 레벨의 콘텐츠를 준비하고 있어요',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('학습으로 돌아가기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultQuiz(ThemeData theme, QuizSessionState session) {
    final question = session.currentQuestion!;
    final progress = session.progress;

    return _buildPopScope(
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  QuizHeader(
                    title: _headerTitle(session),
                    count: session.headerCount,
                    onBack: () async {
                      final shouldPop = await _onWillPop();
                      if (shouldPop && mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: QuizProgressBar(
                      progress: progress,
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
                        showFurigana:
                            ref.watch(quizSettingsProvider).showFurigana,
                        onSelect: _handleAnswer,
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
                    onNext: _handleNext,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
