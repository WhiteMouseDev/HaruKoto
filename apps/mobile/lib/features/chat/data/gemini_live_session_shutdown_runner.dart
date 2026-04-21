import 'dart:async';

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
