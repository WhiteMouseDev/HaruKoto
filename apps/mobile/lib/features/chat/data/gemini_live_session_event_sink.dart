import 'gemini_live_events.dart';
import 'gemini_live_lifecycle_controller.dart';
import 'gemini_live_transcript.dart';

class GeminiLiveSessionEventSink {
  const GeminiLiveSessionEventSink({
    required this.lifecycleController,
    required this.emitState,
    required this.emitAiTextDelta,
    required this.emitTranscriptEntry,
    required this.emitError,
  });

  final GeminiLiveLifecycleController lifecycleController;
  final void Function(GeminiLiveState state) emitState;
  final void Function(String text) emitAiTextDelta;
  final void Function(TranscriptEntry entry) emitTranscriptEntry;
  final void Function(String message) emitError;

  void emitStateIfActive(GeminiLiveState state) {
    if (lifecycleController.isDisposed) return;
    emitState(state);
  }

  void emitConnectingState() {
    emitStateIfActive(GeminiLiveState.connecting);
  }

  void emitErrorState() {
    emitStateIfActive(GeminiLiveState.error);
  }

  void emitEndingState() {
    emitStateIfActive(GeminiLiveState.ending);
  }

  void emitEndedState() {
    emitStateIfActive(GeminiLiveState.ended);
  }
}
