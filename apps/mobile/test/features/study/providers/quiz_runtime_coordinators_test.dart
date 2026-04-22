import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/services/sound_service.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_question_model.dart';
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
}

QuizSessionState _session({
  bool loading = false,
  bool answered = false,
  String? resolvedMode,
}) {
  return QuizSessionState(
    loading: loading,
    sessionId: 'session-1',
    sessionQuizType: 'VOCABULARY',
    questions: const [
      QuizQuestionModel(
        questionId: 'q1',
        questionText: 'question',
        options: [
          QuizOption(id: 'a', text: 'A'),
          QuizOption(id: 'b', text: 'B'),
        ],
        correctOptionId: 'a',
      ),
    ],
    answered: answered,
    resolvedMode: resolvedMode,
  );
}

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
