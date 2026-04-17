import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/haptic_service.dart';
import '../../../core/services/sound_service.dart';
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

  void _handleAnswer(String optionId) {
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

  void _handleNext() {
    final session = ref.read(quizSessionProvider);
    if (session.isLastQuestion) {
      unawaited(_completeQuiz());
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

  Future<void> _requestPop() async {
    final shouldPop = await _onWillPop();
    if (shouldPop && mounted) {
      Navigator.of(context).pop();
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

    return _buildPopScope(child: content);
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
          await _requestPop();
        }
      },
      child: child,
    );
  }
}
