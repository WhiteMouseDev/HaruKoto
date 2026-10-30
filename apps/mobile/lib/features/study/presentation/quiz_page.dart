import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_exception.dart';
import '../providers/quiz_progress_refresh_provider.dart';
import '../providers/quiz_runtime_coordinators.dart';
import '../providers/quiz_session_provider.dart';
import 'quiz_result_page.dart';
import 'widgets/quiz_page_content.dart';

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
  final String? sourceSessionId;

  const QuizPage({
    super.key,
    this.quizType = 'VOCABULARY',
    this.jlptLevel = 'N5',
    this.count = 10,
    this.mode,
    this.resumeSessionId,
    this.stageId,
    this.sourceSessionId,
  });

  @override
  ConsumerState<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends ConsumerState<QuizPage> {
  bool _savingOnExit = false;
  ProviderContainer? _container;
  late final QuizTimerCoordinator _timerCoordinator;
  late final QuizFeedbackPlayer _feedbackPlayer;
  late final QuizInteractionCoordinator _interactionCoordinator;
  late final QuizSessionLifecycleCoordinator _lifecycleCoordinator;
  late final QuizCompletionCoordinator _completionCoordinator;
  late final QuizExitCoordinator _exitCoordinator;

  @override
  void initState() {
    super.initState();
    _timerCoordinator = QuizTimerCoordinator();
    _feedbackPlayer = QuizFeedbackPlayer.defaultServices();
    _interactionCoordinator = QuizInteractionCoordinator(
      timerCoordinator: _timerCoordinator,
      feedbackPlayer: _feedbackPlayer,
    );
    _lifecycleCoordinator = QuizSessionLifecycleCoordinator(
      timerCoordinator: _timerCoordinator,
    );
    _completionCoordinator = QuizCompletionCoordinator(
      timerCoordinator: _timerCoordinator,
      feedbackPlayer: _feedbackPlayer,
    );
    _exitCoordinator = const QuizExitCoordinator();
    Future(_initializeQuiz);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container = ProviderScope.containerOf(context, listen: false);
  }

  @override
  void dispose() {
    final container = _container;
    _lifecycleCoordinator.dispose(
      invalidateSession: () {
        if (container == null) return;
        container.invalidate(quizSessionProvider);
        container.read(quizProgressRefreshProvider).refresh();
      },
    );
    super.dispose();
  }

  Future<void> _initializeQuiz() async {
    await _lifecycleCoordinator.initialize(
      request: QuizSessionRequest(
        quizType: widget.quizType,
        jlptLevel: widget.jlptLevel,
        count: widget.count,
        mode: widget.mode,
        resumeSessionId: widget.resumeSessionId,
        stageId: widget.stageId,
        sourceSessionId: widget.sourceSessionId,
      ),
      initializeSession: ref.read(quizSessionProvider.notifier).initialize,
      isActive: () => mounted,
      onInitialized: _restartTimerIfNeeded,
    );
  }

  void _restartTimerIfNeeded() {
    final notifier = ref.read(quizSessionProvider.notifier);
    final session = ref.read(quizSessionProvider);
    _timerCoordinator.restartIfNeeded(
      session: session,
      resetTimer: notifier.resetTimer,
      incrementTimer: notifier.incrementTimer,
    );
  }

  void _handleAnswer(String optionId) {
    final notifier = ref.read(quizSessionProvider.notifier);
    final session = ref.read(quizSessionProvider);
    _interactionCoordinator.answer(
      optionId: optionId,
      session: session,
      fallbackQuizType: widget.quizType,
      answerCurrentQuestion: notifier.answerCurrentQuestion,
      readSession: () => ref.read(quizSessionProvider),
    );
  }

  void _handleNext() {
    final notifier = ref.read(quizSessionProvider.notifier);
    final session = ref.read(quizSessionProvider);
    _interactionCoordinator.next(
      session: session,
      advanceToNextQuestion: notifier.advanceToNextQuestion,
      restartTimer: _restartTimerIfNeeded,
      completeQuiz: () {
        unawaited(_completeQuiz());
      },
    );
  }

  Future<void> _completeQuiz() async {
    await _completionCoordinator.complete(
      completeQuiz: ref.read(quizSessionProvider.notifier).completeQuiz,
      readSession: () => ref.read(quizSessionProvider),
      isActive: () => mounted,
      navigateToResult: _openQuizResult,
      onError: _showCompletionError,
      fallbackQuizType: widget.quizType,
      jlptLevel: widget.jlptLevel,
      stageId: widget.stageId,
    );
  }

  void _openQuizResult(QuizCompletionDestination destination) {
    unawaited(Navigator.of(context, rootNavigator: true).pushReplacement(
      quizRoute(QuizResultPage(
        result: destination.result,
        quizType: destination.quizType,
        jlptLevel: destination.jlptLevel,
        sessionId: destination.sessionId,
        returnToPreviousResult: widget.sourceSessionId != null,
      )),
    ));
  }

  void _showCompletionError(Object error) {
    debugPrint('Failed to complete quiz: $error');
  }

  Future<void> _requestPop() async {
    if (_savingOnExit || ref.read(quizSessionProvider).completing) return;
    await _exitCoordinator.requestExit(
      confirmExit: () async {
        if (!await _confirmExit() || !mounted) return false;
        setState(() => _savingOnExit = true);
        try {
          await ref.read(quizSessionProvider.notifier).flushPendingAnswers();
          return true;
        } on ApiException catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error.userMessage)),
            );
          }
          return false;
        } finally {
          if (mounted) setState(() => _savingOnExit = false);
        }
      },
      isActive: () => mounted,
      exit: () => Navigator.of(context).pop(),
    );
  }

  Future<bool> _confirmExit() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('퀴즈를 종료할까요?'),
        content: const Text('저장된 답안부터 이어서 학습할 수 있어요. 저장하지 못한 답안은 다시 풀어야 해요.'),
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

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(quizSessionProvider);
    final content = QuizPageContent(
      session: session,
      quizType: widget.quizType,
      jlptLevel: widget.jlptLevel,
      onBackRequested: () {
        unawaited(_requestPop());
      },
      onExit: () => Navigator.of(context).pop(),
      exitLabel: widget.sourceSessionId != null ? '결과로 돌아가기' : '학습으로 돌아가기',
      // Starting a new quiz is not idempotent: a lost start response must not
      // automatically complete that session and create another on retry.
      onRetryLoad:
          widget.resumeSessionId == null && widget.sourceSessionId == null
              ? null
              : () => unawaited(_initializeQuiz()),
      onAnswer: _handleAnswer,
      onNext: _handleNext,
      onComplete: () {
        unawaited(_completeQuiz());
      },
      onSubmitSpecialAnswer: _submitSpecialAnswer,
    );

    if (session.loading || session.questions.isEmpty) {
      return content;
    }

    return _buildPopScope(
      child: Stack(
        children: [
          content,
          if (_savingOnExit) ...[
            const ModalBarrier(dismissible: false, color: Colors.black26),
            const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('답안을 저장하고 있어요'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _submitSpecialAnswer(
    String qId,
    bool isCorrect,
    String questionType, {
    String? optionId,
  }) {
    _interactionCoordinator.submitSpecialAnswer(
      questionId: qId,
      isCorrect: isCorrect,
      questionType: questionType,
      optionId: optionId,
      submitSpecialAnswer:
          ref.read(quizSessionProvider.notifier).submitSpecialAnswer,
    );
  }

  Widget _buildPopScope({required Widget child}) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          await _requestPop();
        }
      },
      child: child,
    );
  }
}
