import 'dart:async';

import '../../../core/services/haptic_service.dart';
import '../../../core/services/sound_service.dart';
import 'quiz_session_provider.dart';

typedef QuizTimerAction = void Function();
typedef QuizPeriodicTimerFactory = Timer Function(
  Duration duration,
  void Function(Timer timer) callback,
);
typedef QuizHapticAction = Future<void> Function();
typedef QuizSoundAction = Future<void> Function(SoundType type);

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
