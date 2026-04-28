import 'dart:async';

import 'gemini_live_events.dart';
import 'gemini_live_greeting_sender.dart';
import 'gemini_live_reconnect_coordinator.dart';

class GeminiLiveSetupCompleteHandler {
  GeminiLiveSetupCompleteHandler({
    required GeminiLiveReconnectCoordinator reconnectCoordinator,
    required GeminiLiveGreetingSender greetingSender,
    required Future<void> Function() startRecording,
    required void Function(GeminiLiveState state) emitState,
  })  : _reconnectCoordinator = reconnectCoordinator,
        _greetingSender = greetingSender,
        _startRecording = startRecording,
        _emitState = emitState;

  final GeminiLiveReconnectCoordinator _reconnectCoordinator;
  final GeminiLiveGreetingSender _greetingSender;
  final Future<void> Function() _startRecording;
  final void Function(GeminiLiveState state) _emitState;
  bool _recordingStarted = false;

  void handle() {
    _reconnectCoordinator.markConnected();
    _emitState(GeminiLiveState.connected);
    _greetingSender.send();
  }

  void handleModelTurnComplete() {
    if (_recordingStarted) return;
    _recordingStarted = true;
    unawaited(_startRecording());
  }
}
