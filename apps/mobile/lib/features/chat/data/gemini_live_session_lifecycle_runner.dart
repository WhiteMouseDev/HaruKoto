import 'dart:async';

import 'package:flutter/foundation.dart';

import 'gemini_live_lifecycle_controller.dart';
import 'gemini_live_reconnect_coordinator.dart';

typedef GeminiLiveLifecycleAsyncAction = Future<void> Function();
typedef GeminiLiveLifecycleSyncAction = void Function();
typedef GeminiLiveLifecycleErrorEmitter = void Function(String message);

class GeminiLiveSessionLifecycleRunner {
  const GeminiLiveSessionLifecycleRunner({
    required GeminiLiveLifecycleController lifecycleController,
    required GeminiLiveReconnectCoordinator reconnectCoordinator,
    required GeminiLiveLifecycleAsyncAction connect,
    required GeminiLiveLifecycleAsyncAction stopRecording,
    required GeminiLiveLifecycleAsyncAction disposeAudio,
    required GeminiLiveLifecycleAsyncAction closeTransport,
    required GeminiLiveLifecycleSyncAction flushTranscripts,
    required GeminiLiveLifecycleSyncAction emitConnectingState,
    required GeminiLiveLifecycleSyncAction emitErrorState,
    required GeminiLiveLifecycleSyncAction emitEndingState,
    required GeminiLiveLifecycleSyncAction emitEndedState,
    required GeminiLiveLifecycleErrorEmitter emitError,
  })  : _lifecycleController = lifecycleController,
        _reconnectCoordinator = reconnectCoordinator,
        _connect = connect,
        _stopRecording = stopRecording,
        _disposeAudio = disposeAudio,
        _closeTransport = closeTransport,
        _flushTranscripts = flushTranscripts,
        _emitConnectingState = emitConnectingState,
        _emitErrorState = emitErrorState,
        _emitEndingState = emitEndingState,
        _emitEndedState = emitEndedState,
        _emitError = emitError;

  final GeminiLiveLifecycleController _lifecycleController;
  final GeminiLiveReconnectCoordinator _reconnectCoordinator;
  final GeminiLiveLifecycleAsyncAction _connect;
  final GeminiLiveLifecycleAsyncAction _stopRecording;
  final GeminiLiveLifecycleAsyncAction _disposeAudio;
  final GeminiLiveLifecycleAsyncAction _closeTransport;
  final GeminiLiveLifecycleSyncAction _flushTranscripts;
  final GeminiLiveLifecycleSyncAction _emitConnectingState;
  final GeminiLiveLifecycleSyncAction _emitErrorState;
  final GeminiLiveLifecycleSyncAction _emitEndingState;
  final GeminiLiveLifecycleSyncAction _emitEndedState;
  final GeminiLiveLifecycleErrorEmitter _emitError;

  Future<void> start({required String model}) async {
    if (model.isEmpty) {
      _emitError('음성 모델이 설정되지 않았습니다');
      _emitErrorState();
      return;
    }

    _lifecycleController.markStarted();
    _reconnectCoordinator.resetForStart();
    _emitConnectingState();

    try {
      await _connect();
    } catch (e) {
      debugPrint('[GeminiLive] Start failed: $e');
      _emitError('연결에 실패했습니다');
      _emitErrorState();
    }
  }

  Future<void> end() async {
    _lifecycleController.markEnding();
    _emitEndingState();
    _flushTranscripts();
    await _stopRecording();
    unawaited(_closeTransport());
    _emitEndedState();
  }

  Future<void> dispose() async {
    _lifecycleController.markDisposed();
    await _disposeAudio();
    unawaited(_closeTransport());
  }
}
