import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/services/sound_service.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_question_model.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_result_model.dart';
import 'package:harukoto_mobile/features/study/providers/quiz_runtime_coordinators.dart';
import 'package:harukoto_mobile/features/study/providers/quiz_session_provider.dart';

void main() {
  group('QuizTimerCoordinator', () {
    test('starts a timer for active standard quiz questions', () {
      final timers = _FakeTimerFactory();
      final coordinator = QuizTimerCoordinator(createTimer: timers.create);
      var resetCount = 0;
      var tickCount = 0;

      coordinator.restartIfNeeded(
        session: _session(),
        resetTimer: () => resetCount++,
        incrementTimer: () => tickCount++,
      );

      expect(coordinator.isActive, isTrue);
      expect(resetCount, 1);
      expect(timers.createdTimers, hasLength(1));

      timers.createdTimers.single.fire();
      expect(tickCount, 1);
    });

    test('does not start a timer for inactive quiz states', () {
      final timers = _FakeTimerFactory();
      final coordinator = QuizTimerCoordinator(createTimer: timers.create);
      var resetCount = 0;

      for (final session in [
        _session(loading: true),
        const QuizSessionState(loading: false),
        _session(answered: true),
        _session(resolvedMode: 'matching'),
      ]) {
        coordinator.restartIfNeeded(
          session: session,
          resetTimer: () => resetCount++,
          incrementTimer: () {},
        );
      }

      expect(coordinator.isActive, isFalse);
      expect(resetCount, 0);
      expect(timers.createdTimers, isEmpty);
    });

    test('restarting cancels the previous timer', () {
      final timers = _FakeTimerFactory();
      final coordinator = QuizTimerCoordinator(createTimer: timers.create);

      coordinator.restartIfNeeded(
        session: _session(),
        resetTimer: () {},
        incrementTimer: () {},
      );
      final firstTimer = timers.createdTimers.single;

      coordinator.restartIfNeeded(
        session: _session(),
        resetTimer: () {},
        incrementTimer: () {},
      );

      expect(firstTimer.isActive, isFalse);
      expect(timers.createdTimers.last.isActive, isTrue);
    });
  });

  group('QuizFeedbackPlayer', () {
    test('plays correct feedback below combo threshold', () {
      final events = <Object>[];
      final player = _buildFeedbackPlayer(events);

      player.playAnswerFeedback(isCorrect: true, streak: 2);

      expect(events, ['medium', SoundType.correct]);
    });

    test('plays combo feedback at combo threshold', () {
      final events = <Object>[];
      final player = _buildFeedbackPlayer(events);

      player.playAnswerFeedback(isCorrect: true, streak: 3);

      expect(events, ['heavy', SoundType.combo]);
    });

    test('plays wrong and completion feedback', () {
      final events = <Object>[];
      final player = _buildFeedbackPlayer(events);

      player.playAnswerFeedback(isCorrect: false, streak: 0);
      player.playCompletionFeedback();

      expect(events, [
        'heavy',
        SoundType.wrong,
        'heavy',
        SoundType.complete,
      ]);
    });
  });

  group('QuizInteractionCoordinator', () {
    test('answers current question, stops timer, and plays updated feedback',
        () {
      final timers = _FakeTimerFactory();
      final timerCoordinator = QuizTimerCoordinator(createTimer: timers.create);
      timerCoordinator.restartIfNeeded(
        session: _session(),
        resetTimer: () {},
        incrementTimer: () {},
      );

      final events = <Object>[];
      final coordinator = QuizInteractionCoordinator(
        timerCoordinator: timerCoordinator,
        feedbackPlayer: _buildFeedbackPlayer(events),
      );
      String? answeredOptionId;
      String? answeredQuestionType;

      final outcome = coordinator.answer(
        optionId: 'o1',
        session: _session(sessionQuizType: 'MATCHING'),
        fallbackQuizType: 'VOCABULARY',
        answerCurrentQuestion: ({
          required String optionId,
          required String questionType,
        }) {
          answeredOptionId = optionId;
          answeredQuestionType = questionType;
          return true;
        },
        readSession: () => _session(streak: 3),
      );

      expect(outcome, QuizAnswerOutcome.answered);
      expect(timerCoordinator.isActive, isFalse);
      expect(answeredOptionId, 'o1');
      expect(answeredQuestionType, 'MATCHING');
      expect(events, ['heavy', SoundType.combo]);
    });

    test('ignores unanswered results without reading streak or feedback', () {
      final timers = _FakeTimerFactory();
      final timerCoordinator = QuizTimerCoordinator(createTimer: timers.create);
      timerCoordinator.restartIfNeeded(
        session: _session(),
        resetTimer: () {},
        incrementTimer: () {},
      );

      final events = <Object>[];
      final coordinator = QuizInteractionCoordinator(
        timerCoordinator: timerCoordinator,
        feedbackPlayer: _buildFeedbackPlayer(events),
      );
      var readSession = false;

      final outcome = coordinator.answer(
        optionId: 'o1',
        session: _session(),
        fallbackQuizType: 'VOCABULARY',
        answerCurrentQuestion: ({
          required String optionId,
          required String questionType,
        }) =>
            null,
        readSession: () {
          readSession = true;
          return _session(streak: 3);
        },
      );

      expect(outcome, QuizAnswerOutcome.ignored);
      expect(timerCoordinator.isActive, isFalse);
      expect(readSession, isFalse);
      expect(events, isEmpty);
    });

    test('completes instead of advancing from the last question', () {
      final coordinator = QuizInteractionCoordinator(
        timerCoordinator: QuizTimerCoordinator(
          createTimer: _FakeTimerFactory().create,
        ),
        feedbackPlayer: _buildFeedbackPlayer([]),
      );
      var advanced = false;
      var restarted = false;
      var completed = false;

      final outcome = coordinator.next(
        session: _session(),
        advanceToNextQuestion: () {
          advanced = true;
        },
        restartTimer: () {
          restarted = true;
        },
        completeQuiz: () {
          completed = true;
        },
      );

      expect(outcome, QuizProgressionOutcome.completing);
      expect(advanced, isFalse);
      expect(restarted, isFalse);
      expect(completed, isTrue);
    });

    test('advances and restarts the timer before the last question', () {
      final coordinator = QuizInteractionCoordinator(
        timerCoordinator: QuizTimerCoordinator(
          createTimer: _FakeTimerFactory().create,
        ),
        feedbackPlayer: _buildFeedbackPlayer([]),
      );
      var advanced = false;
      var restarted = false;
      var completed = false;

      final outcome = coordinator.next(
        session: _session(questions: const [_question, _secondQuestion]),
        advanceToNextQuestion: () {
          advanced = true;
        },
        restartTimer: () {
          restarted = true;
        },
        completeQuiz: () {
          completed = true;
        },
      );

      expect(outcome, QuizProgressionOutcome.advanced);
      expect(advanced, isTrue);
      expect(restarted, isTrue);
      expect(completed, isFalse);
    });

    test('forwards special answers to the session action', () {
      final coordinator = QuizInteractionCoordinator(
        timerCoordinator: QuizTimerCoordinator(
          createTimer: _FakeTimerFactory().create,
        ),
        feedbackPlayer: _buildFeedbackPlayer([]),
      );
      String? capturedQuestionId;
      bool? capturedIsCorrect;
      String? capturedQuestionType;
      String? capturedOptionId;

      coordinator.submitSpecialAnswer(
        questionId: 'q1',
        isCorrect: true,
        questionType: 'CLOZE',
        optionId: 'o1',
        submitSpecialAnswer: ({
          required String questionId,
          required bool isCorrect,
          required String questionType,
          String? optionId,
        }) {
          capturedQuestionId = questionId;
          capturedIsCorrect = isCorrect;
          capturedQuestionType = questionType;
          capturedOptionId = optionId;
        },
      );

      expect(capturedQuestionId, 'q1');
      expect(capturedIsCorrect, isTrue);
      expect(capturedQuestionType, 'CLOZE');
      expect(capturedOptionId, 'o1');
    });
  });

  group('QuizSessionLifecycleCoordinator', () {
    test('initializes a session and runs post-initialize work while active',
        () async {
      final timerCoordinator = QuizTimerCoordinator(
        createTimer: _FakeTimerFactory().create,
      );
      final coordinator = QuizSessionLifecycleCoordinator(
        timerCoordinator: timerCoordinator,
      );
      const request = QuizSessionRequest(
        quizType: 'VOCABULARY',
        jlptLevel: 'N5',
        count: 10,
        stageId: 'stage-1',
      );
      QuizSessionRequest? capturedRequest;
      var restarted = false;

      final outcome = await coordinator.initialize(
        request: request,
        initializeSession: (value) async {
          capturedRequest = value;
        },
        isActive: () => true,
        onInitialized: () {
          restarted = true;
        },
      );

      expect(outcome, QuizInitializationOutcome.initialized);
      expect(capturedRequest, same(request));
      expect(restarted, isTrue);
    });

    test('skips post-initialize work after the page becomes inactive',
        () async {
      final coordinator = QuizSessionLifecycleCoordinator(
        timerCoordinator: QuizTimerCoordinator(
          createTimer: _FakeTimerFactory().create,
        ),
      );
      var restarted = false;

      final outcome = await coordinator.initialize(
        request: const QuizSessionRequest(
          quizType: 'VOCABULARY',
          jlptLevel: 'N5',
          count: 10,
        ),
        initializeSession: (_) async {},
        isActive: () => false,
        onInitialized: () {
          restarted = true;
        },
      );

      expect(outcome, QuizInitializationOutcome.inactive);
      expect(restarted, isFalse);
    });

    test('disposes the timer and defers session invalidation', () {
      final timers = _FakeTimerFactory();
      final timerCoordinator = QuizTimerCoordinator(createTimer: timers.create);
      timerCoordinator.restartIfNeeded(
        session: _session(),
        resetTimer: () {},
        incrementTimer: () {},
      );
      final deferredActions = <void Function()>[];
      final coordinator = QuizSessionLifecycleCoordinator(
        timerCoordinator: timerCoordinator,
        deferAction: deferredActions.add,
      );
      var invalidated = false;

      coordinator.dispose(
        invalidateSession: () {
          invalidated = true;
        },
      );

      expect(timerCoordinator.isActive, isFalse);
      expect(invalidated, isFalse);
      expect(deferredActions, hasLength(1));

      deferredActions.single();

      expect(invalidated, isTrue);
    });
  });

  group('QuizCompletionCoordinator', () {
    test('stops timer, plays feedback, and opens result destination', () async {
      final timers = _FakeTimerFactory();
      final timerCoordinator = QuizTimerCoordinator(createTimer: timers.create);
      timerCoordinator.restartIfNeeded(
        session: _session(),
        resetTimer: () {},
        incrementTimer: () {},
      );

      final events = <Object>[];
      final coordinator = QuizCompletionCoordinator(
        timerCoordinator: timerCoordinator,
        feedbackPlayer: _buildFeedbackPlayer(events),
      );
      QuizCompletionDestination? destination;
      String? completedStageId;

      final outcome = await coordinator.complete(
        completeQuiz: ({String? stageId}) async {
          completedStageId = stageId;
          return _result;
        },
        readSession: () => _session(sessionQuizType: 'MATCHING'),
        isActive: () => true,
        navigateToResult: (value) => destination = value,
        onError: (_) {},
        fallbackQuizType: 'VOCABULARY',
        jlptLevel: 'N4',
        stageId: 'stage-1',
      );

      expect(outcome, QuizCompletionOutcome.completed);
      expect(timerCoordinator.isActive, isFalse);
      expect(completedStageId, 'stage-1');
      expect(events, ['heavy', SoundType.complete]);
      expect(destination, isNotNull);
      expect(destination!.result, _result);
      expect(destination!.quizType, 'VOCABULARY');
      expect(destination!.jlptLevel, 'N4');
      expect(destination!.sessionId, 'session-1');
    });

    test('ignores null completion results without feedback or navigation',
        () async {
      final events = <Object>[];
      final coordinator = QuizCompletionCoordinator(
        timerCoordinator: QuizTimerCoordinator(
          createTimer: _FakeTimerFactory().create,
        ),
        feedbackPlayer: _buildFeedbackPlayer(events),
      );
      var navigated = false;

      final outcome = await coordinator.complete(
        completeQuiz: ({String? stageId}) async => null,
        readSession: _session,
        isActive: () => true,
        navigateToResult: (_) => navigated = true,
        onError: (_) {},
        fallbackQuizType: 'VOCABULARY',
        jlptLevel: 'N5',
      );

      expect(outcome, QuizCompletionOutcome.ignored);
      expect(events, isEmpty);
      expect(navigated, isFalse);
    });

    test('reports completion failures', () async {
      final coordinator = QuizCompletionCoordinator(
        timerCoordinator: QuizTimerCoordinator(
          createTimer: _FakeTimerFactory().create,
        ),
        feedbackPlayer: _buildFeedbackPlayer([]),
      );
      Object? reportedError;

      final outcome = await coordinator.complete(
        completeQuiz: ({String? stageId}) async => throw StateError('boom'),
        readSession: _session,
        isActive: () => true,
        navigateToResult: (_) {},
        onError: (error) => reportedError = error,
        fallbackQuizType: 'VOCABULARY',
        jlptLevel: 'N5',
      );

      expect(outcome, QuizCompletionOutcome.failed);
      expect(reportedError, isA<StateError>());
    });

    test('does not read session after completion if the page is inactive',
        () async {
      final coordinator = QuizCompletionCoordinator(
        timerCoordinator: QuizTimerCoordinator(
          createTimer: _FakeTimerFactory().create,
        ),
        feedbackPlayer: _buildFeedbackPlayer([]),
      );
      var readSession = false;

      final outcome = await coordinator.complete(
        completeQuiz: ({String? stageId}) async => _result,
        readSession: () {
          readSession = true;
          return _session();
        },
        isActive: () => false,
        navigateToResult: (_) {},
        onError: (_) {},
        fallbackQuizType: 'VOCABULARY',
        jlptLevel: 'N5',
      );

      expect(outcome, QuizCompletionOutcome.ignored);
      expect(readSession, isFalse);
    });
  });

  group('QuizExitCoordinator', () {
    test('exits after confirmation while active', () async {
      const coordinator = QuizExitCoordinator();
      var exited = false;

      final outcome = await coordinator.requestExit(
        confirmExit: () async => true,
        isActive: () => true,
        exit: () {
          exited = true;
        },
      );

      expect(outcome, QuizExitOutcome.exited);
      expect(exited, isTrue);
    });

    test('does not exit after cancellation', () async {
      const coordinator = QuizExitCoordinator();
      var exited = false;

      final outcome = await coordinator.requestExit(
        confirmExit: () async => false,
        isActive: () => true,
        exit: () {
          exited = true;
        },
      );

      expect(outcome, QuizExitOutcome.cancelled);
      expect(exited, isFalse);
    });

    test('does not exit when inactive after confirmation', () async {
      const coordinator = QuizExitCoordinator();
      var exited = false;

      final outcome = await coordinator.requestExit(
        confirmExit: () async => true,
        isActive: () => false,
        exit: () {
          exited = true;
        },
      );

      expect(outcome, QuizExitOutcome.inactive);
      expect(exited, isFalse);
    });
  });
}

QuizSessionState _session({
  bool loading = false,
  bool answered = false,
  int currentIndex = 0,
  String sessionQuizType = 'VOCABULARY',
  List<QuizQuestionModel> questions = const [_question],
  String? resolvedMode,
  int streak = 0,
}) {
  return QuizSessionState(
    loading: loading,
    sessionId: 'session-1',
    sessionQuizType: sessionQuizType,
    questions: questions,
    currentIndex: currentIndex,
    answered: answered,
    resolvedMode: resolvedMode,
    streak: streak,
  );
}

const _question = QuizQuestionModel(
  questionId: 'q1',
  questionText: 'question',
  options: [
    QuizOption(id: 'a', text: 'A'),
    QuizOption(id: 'b', text: 'B'),
  ],
  correctOptionId: 'a',
);

const _secondQuestion = QuizQuestionModel(
  questionId: 'q2',
  questionText: 'question 2',
  options: [
    QuizOption(id: 'c', text: 'C'),
    QuizOption(id: 'd', text: 'D'),
  ],
  correctOptionId: 'c',
);

const _result = QuizResultModel(
  correctCount: 1,
  totalQuestions: 1,
  xpEarned: 10,
  accuracy: 100,
  currentXp: 20,
  xpForNext: 100,
  level: 1,
  events: [],
);

QuizFeedbackPlayer _buildFeedbackPlayer(List<Object> events) {
  return QuizFeedbackPlayer(
    mediumHaptic: () async {
      events.add('medium');
    },
    heavyHaptic: () async {
      events.add('heavy');
    },
    playSound: (type) async {
      events.add(type);
    },
  );
}

class _FakeTimerFactory {
  final createdTimers = <_FakeTimer>[];

  Timer create(Duration duration, void Function(Timer timer) callback) {
    final timer = _FakeTimer(callback);
    createdTimers.add(timer);
    return timer;
  }
}

class _FakeTimer implements Timer {
  _FakeTimer(this._callback);

  final void Function(Timer timer) _callback;
  var _active = true;
  var _tick = 0;

  void fire() {
    if (!_active) return;
    _tick++;
    _callback(this);
  }

  @override
  bool get isActive => _active;

  @override
  int get tick => _tick;

  @override
  void cancel() {
    _active = false;
  }
}
