import 'dart:async';

import 'package:flutter/foundation.dart';

import 'gemini_live_lifecycle_actions.dart';
import 'gemini_live_lifecycle_controller.dart';

class GeminiLiveSessionShutdownRunner {
  const GeminiLiveSessionShutdownRunner({
    required GeminiLiveLifecycleController lifecycleController,
    required GeminiLiveLifecycleAsyncAction stopRecording,
    required GeminiLiveLifecycleAsyncAction disposeAudio,
    required GeminiLiveLifecycleAsyncAction closeTransport,
    required GeminiLiveLifecycleSyncAction flushTranscripts,
    required GeminiLiveLifecycleSyncAction emitEndingState,
    required GeminiLiveLifecycleSyncAction emitEndedState,
  })  : _lifecycleController = lifecycleController,
        _stopRecording = stopRecording,
        _disposeAudio = disposeAudio,
        _closeTransport = closeTransport,
        _flushTranscripts = flushTranscripts,
        _emitEndingState = emitEndingState,
        _emitEndedState = emitEndedState;

  final GeminiLiveLifecycleController _lifecycleController;
  final GeminiLiveLifecycleAsyncAction _stopRecording;
  final GeminiLiveLifecycleAsyncAction _disposeAudio;
  final GeminiLiveLifecycleAsyncAction _closeTransport;
  final GeminiLiveLifecycleSyncAction _flushTranscripts;
  final GeminiLiveLifecycleSyncAction _emitEndingState;
  final GeminiLiveLifecycleSyncAction _emitEndedState;

  Future<void> end() async {
    _lifecycleController.markEnding();
    _emitEndingState();
    _flushTranscripts();
    // Disconnect independently of native audio teardown. A slow or failing
    // plugin must not leave a terminated call connected to the model.
    unawaited(_closeTransportSafely());
    try {
      await _stopRecording();
    } finally {
      _emitEndedState();
    }
  }

  Future<void> dispose() async {
    _lifecycleController.markDisposed();
    unawaited(_closeTransportSafely());
    await _disposeAudio();
  }

  Future<void> _closeTransportSafely() async {
    try {
      await _closeTransport();
    } catch (error) {
      debugPrint('[GeminiLive] Socket cleanup failed: $error');
    }
  }
}
