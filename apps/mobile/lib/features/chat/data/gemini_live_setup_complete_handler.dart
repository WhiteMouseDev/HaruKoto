import 'dart:async';

import 'gemini_live_events.dart';
import 'gemini_live_greeting_sender.dart';
import 'gemini_live_reconnect_coordinator.dart';

class GeminiLiveSetupCompleteHandler {
  GeminiLiveSetupCompleteHandler({
    required GeminiLiveReconnectCoordinator reconnectCoordinator,
    required GeminiLiveGreetingSender greetingSender,
    required Future<bool> Function() preparePlayback,
    required Future<void> Function() startRecording,
    required void Function(GeminiLiveState state) emitState,
    Duration greetingTimeout = const Duration(seconds: 8),
  })  : _reconnectCoordinator = reconnectCoordinator,
        _greetingSender = greetingSender,
        _preparePlayback = preparePlayback,
        _startRecording = startRecording,
        _emitState = emitState,
        _greetingTimeout = greetingTimeout;

  final GeminiLiveReconnectCoordinator _reconnectCoordinator;
  final GeminiLiveGreetingSender _greetingSender;
  final Future<bool> Function() _preparePlayback;
  final Future<void> Function() _startRecording;
  final void Function(GeminiLiveState state) _emitState;
  final Duration _greetingTimeout;
  Timer? _greetingTimer;
  bool _recordingStarted = false;
  bool _greetingStarted = false;

  void handle() {
    _reconnectCoordinator.markConnected();
    _emitState(GeminiLiveState.connected);
    if (!_greetingStarted) {
      _greetingStarted = true;
      unawaited(_preparePlaybackAndSendGreeting());
    } else {
      // The first greeting's turnComplete may have been lost when the previous
      // connection closed. A resumed session can be waiting for user input.
      _startRecordingOnce();
    }
  }

  void handleModelTurnComplete() {
    _startRecordingOnce();
  }

  void _startRecordingOnce() {
    cancelPendingGreeting();
    if (_recordingStarted) return;
    _recordingStarted = true;
    unawaited(_startRecording());
  }

  Future<void> _preparePlaybackAndSendGreeting() async {
    if (!await _preparePlayback()) return;
    _greetingSender.send();
    if (!_recordingStarted) {
      // A proactive model may stay silent instead of completing the greeting.
      // Allow learner input after a bounded wait without sending another turn.
      _greetingTimer = Timer(_greetingTimeout, _startRecordingOnce);
    }
  }

  void cancelPendingGreeting() {
    _greetingTimer?.cancel();
    _greetingTimer = null;
  }
}
