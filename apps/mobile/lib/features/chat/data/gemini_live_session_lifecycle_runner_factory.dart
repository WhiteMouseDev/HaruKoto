import 'gemini_live_lifecycle_actions.dart';
import 'gemini_live_lifecycle_controller.dart';
import 'gemini_live_reconnect_coordinator.dart';
import 'gemini_live_session_lifecycle_runner.dart';
import 'gemini_live_session_start_runner.dart';
import 'gemini_live_session_shutdown_runner.dart';

class GeminiLiveSessionLifecycleRunnerFactory {
  const GeminiLiveSessionLifecycleRunnerFactory();

  GeminiLiveSessionLifecycleRunner build({
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
  }) {
    final startRunner = GeminiLiveSessionStartRunner(
      lifecycleController: lifecycleController,
      reconnectCoordinator: reconnectCoordinator,
      connect: connect,
      emitConnectingState: emitConnectingState,
      emitErrorState: emitErrorState,
      emitError: emitError,
    );
    final shutdownRunner = GeminiLiveSessionShutdownRunner(
      lifecycleController: lifecycleController,
      stopRecording: stopRecording,
      disposeAudio: disposeAudio,
      closeTransport: closeTransport,
      flushTranscripts: flushTranscripts,
      emitEndingState: emitEndingState,
      emitEndedState: emitEndedState,
    );

    return GeminiLiveSessionLifecycleRunner(
      startRunner: startRunner,
      shutdownRunner: shutdownRunner,
    );
  }
}
