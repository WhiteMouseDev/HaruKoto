import 'dart:async';

import '../../../core/services/haptic_service.dart';
import '../../../core/services/sound_service.dart';
import '../data/models/quiz_result_model.dart';
import 'quiz_session_provider.dart';

typedef QuizTimerAction = void Function();
typedef QuizPeriodicTimerFactory = Timer Function(
  Duration duration,
  void Function(Timer timer) callback,
);
typedef QuizHapticAction = Future<void> Function();
typedef QuizSoundAction = Future<void> Function(SoundType type);
typedef QuizInitializeAction = Future<void> Function(
    QuizSessionRequest request);
typedef QuizPostInitializeAction = void Function();
typedef QuizSessionInvalidator = void Function();
typedef QuizDeferredAction = void Function(void Function() action);
typedef QuizAnswerAction = bool? Function({
  required String optionId,
  required String questionType,
});
typedef QuizAdvanceAction = void Function();
typedef QuizCompletionTrigger = void Function();
typedef QuizRestartTimerAction = void Function();
typedef QuizSpecialAnswerAction = void Function({
  required String questionId,
  required bool isCorrect,
  required String questionType,
  String? optionId,
});
typedef QuizCompleteAction = Future<QuizResultModel?> Function({
  String? stageId,
});
typedef QuizSessionReader = QuizSessionState Function();
typedef QuizActiveGuard = bool Function();
typedef QuizCompletionNavigator = void Function(
  QuizCompletionDestination destination,
);
typedef QuizCompletionErrorHandler = void Function(Object error);
typedef QuizExitConfirmation = Future<bool> Function();
typedef QuizExitAction = void Function();

enum QuizInitializationOutcome {
  initialized,
  inactive,
}

enum QuizAnswerOutcome {
  answered,
  ignored,
}

enum QuizProgressionOutcome {
  advanced,
  completing,
}

enum QuizCompletionOutcome {
  completed,
  ignored,
  failed,
}

enum QuizExitOutcome {
  exited,
  cancelled,
  inactive,
}

void _defaultDeferQuizAction(void Function() action) {
  unawaited(Future<void>(() {
    action();
  }));
}

class QuizTimerCoordinator {
  QuizTimerCoordinator({
    this.interval = const Duration(seconds: 1),
    QuizPeriodicTimerFactory? createTimer,
  }) : _createTimer = createTimer ?? Timer.periodic;

  final Duration interval;
  final QuizPeriodicTimerFactory _createTimer;
  Timer? _timer;

  bool get isActive => _timer?.isActive ?? false;

  void restartIfNeeded({
    required QuizSessionState session,
    required QuizTimerAction resetTimer,
    required QuizTimerAction incrementTimer,
  }) {
    stop();
    if (!_shouldTrack(session)) {
      return;
    }

    resetTimer();
    _timer = _createTimer(interval, (_) => incrementTimer());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => stop();

  bool _shouldTrack(QuizSessionState session) {
    return !session.loading &&
        session.questions.isNotEmpty &&
        !session.answered &&
        !session.isSpecialMode;
  }
}

class QuizFeedbackPlayer {
  const QuizFeedbackPlayer({
    required this.mediumHaptic,
    required this.heavyHaptic,
    required this.playSound,
  });

  factory QuizFeedbackPlayer.defaultServices() {
    final haptic = HapticService();
    final sound = SoundService();
    return QuizFeedbackPlayer(
      mediumHaptic: haptic.medium,
      heavyHaptic: haptic.heavy,
      playSound: sound.play,
    );
  }

  final QuizHapticAction mediumHaptic;
  final QuizHapticAction heavyHaptic;
  final QuizSoundAction playSound;

  void playAnswerFeedback({
    required bool isCorrect,
    required int streak,
  }) {
    if (isCorrect) {
      final isCombo = streak >= 3;
      unawaited(isCombo ? heavyHaptic() : mediumHaptic());
      unawaited(playSound(isCombo ? SoundType.combo : SoundType.correct));
      return;
    }

    unawaited(heavyHaptic());
    unawaited(playSound(SoundType.wrong));
  }

  void playCompletionFeedback() {
    unawaited(heavyHaptic());
    unawaited(playSound(SoundType.complete));
  }
}

class QuizInteractionCoordinator {
  const QuizInteractionCoordinator({
    required QuizTimerCoordinator timerCoordinator,
    required QuizFeedbackPlayer feedbackPlayer,
  })  : _timerCoordinator = timerCoordinator,
        _feedbackPlayer = feedbackPlayer;

  final QuizTimerCoordinator _timerCoordinator;
  final QuizFeedbackPlayer _feedbackPlayer;

  QuizAnswerOutcome answer({
    required String optionId,
    required QuizSessionState session,
    required String fallbackQuizType,
    required QuizAnswerAction answerCurrentQuestion,
    required QuizSessionReader readSession,
  }) {
    _timerCoordinator.stop();
    final isCorrect = answerCurrentQuestion(
      optionId: optionId,
      questionType: session.effectiveQuizType(fallbackQuizType),
    );
    if (isCorrect == null) {
      return QuizAnswerOutcome.ignored;
    }

    _feedbackPlayer.playAnswerFeedback(
      isCorrect: isCorrect,
      streak: readSession().streak,
    );
    return QuizAnswerOutcome.answered;
  }

  QuizProgressionOutcome next({
    required QuizSessionState session,
    required QuizAdvanceAction advanceToNextQuestion,
    required QuizRestartTimerAction restartTimer,
    required QuizCompletionTrigger completeQuiz,
  }) {
    if (session.isLastQuestion) {
      completeQuiz();
      return QuizProgressionOutcome.completing;
    }

    advanceToNextQuestion();
    restartTimer();
    return QuizProgressionOutcome.advanced;
  }

  void submitSpecialAnswer({
    required String questionId,
    required bool isCorrect,
    required String questionType,
    required QuizSpecialAnswerAction submitSpecialAnswer,
    String? optionId,
  }) {
    submitSpecialAnswer(
      questionId: questionId,
      isCorrect: isCorrect,
      questionType: questionType,
      optionId: optionId,
    );
  }
}

class QuizSessionLifecycleCoordinator {
  const QuizSessionLifecycleCoordinator({
    required QuizTimerCoordinator timerCoordinator,
    QuizDeferredAction deferAction = _defaultDeferQuizAction,
  })  : _timerCoordinator = timerCoordinator,
        _deferAction = deferAction;

  final QuizTimerCoordinator _timerCoordinator;
  final QuizDeferredAction _deferAction;

  Future<QuizInitializationOutcome> initialize({
    required QuizSessionRequest request,
    required QuizInitializeAction initializeSession,
    required QuizActiveGuard isActive,
    required QuizPostInitializeAction onInitialized,
  }) async {
    await initializeSession(request);
    if (!isActive()) {
      return QuizInitializationOutcome.inactive;
    }

    onInitialized();
    return QuizInitializationOutcome.initialized;
  }

  void dispose({
    required QuizSessionInvalidator invalidateSession,
  }) {
    _timerCoordinator.dispose();
    _deferAction(invalidateSession);
  }
}

class QuizCompletionDestination {
  const QuizCompletionDestination({
    required this.result,
    required this.quizType,
    required this.jlptLevel,
    required this.sessionId,
  });

  final QuizResultModel result;
  final String quizType;
  final String jlptLevel;
  final String sessionId;
}

class QuizCompletionCoordinator {
  const QuizCompletionCoordinator({
    required QuizTimerCoordinator timerCoordinator,
    required QuizFeedbackPlayer feedbackPlayer,
  })  : _timerCoordinator = timerCoordinator,
        _feedbackPlayer = feedbackPlayer;

  final QuizTimerCoordinator _timerCoordinator;
  final QuizFeedbackPlayer _feedbackPlayer;

  Future<QuizCompletionOutcome> complete({
    required QuizCompleteAction completeQuiz,
    required QuizSessionReader readSession,
    required QuizActiveGuard isActive,
    required QuizCompletionNavigator navigateToResult,
    required QuizCompletionErrorHandler onError,
    required String fallbackQuizType,
    required String jlptLevel,
    String? stageId,
  }) async {
    _timerCoordinator.stop();

    try {
      final result = await completeQuiz(stageId: stageId);
      if (result == null || !isActive()) {
        return QuizCompletionOutcome.ignored;
      }

      final latestSession = readSession();
      if (!isActive()) {
        return QuizCompletionOutcome.ignored;
      }

      final sessionId = latestSession.sessionId;
      if (sessionId == null) {
        return QuizCompletionOutcome.ignored;
      }

      _feedbackPlayer.playCompletionFeedback();
      navigateToResult(
        QuizCompletionDestination(
          result: result,
          quizType: latestSession.displayQuizType(fallbackQuizType),
          jlptLevel: jlptLevel,
          sessionId: sessionId,
        ),
      );
      return QuizCompletionOutcome.completed;
    } catch (error) {
      onError(error);
      return QuizCompletionOutcome.failed;
    }
  }
}

class QuizExitCoordinator {
  const QuizExitCoordinator();

  Future<QuizExitOutcome> requestExit({
    required QuizExitConfirmation confirmExit,
    required QuizActiveGuard isActive,
    required QuizExitAction exit,
  }) async {
    final shouldExit = await confirmExit();
    if (!shouldExit) {
      return QuizExitOutcome.cancelled;
    }

    if (!isActive()) {
      return QuizExitOutcome.inactive;
    }

    exit();
    return QuizExitOutcome.exited;
  }
}
