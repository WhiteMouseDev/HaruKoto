import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_events.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_lifecycle_controller.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_session_event_sink.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_transcript.dart';

void main() {
  group('GeminiLiveSessionEventSink', () {
    test('emits states while lifecycle is active', () {
      final states = <GeminiLiveState>[];
      final sink = _buildSink(states: states);

      sink.emitConnectingState();
      sink.emitErrorState();
      sink.emitEndingState();
      sink.emitEndedState();

      expect(states, [
        GeminiLiveState.connecting,
        GeminiLiveState.error,
        GeminiLiveState.ending,
        GeminiLiveState.ended,
      ]);
    });

    test('suppresses states after lifecycle is disposed', () {
      final lifecycleController = GeminiLiveLifecycleController();
      final states = <GeminiLiveState>[];
      final sink = _buildSink(
        lifecycleController: lifecycleController,
        states: states,
      );

      lifecycleController.markDisposed();
      sink.emitConnectingState();
      sink.emitErrorState();
      sink.emitEndingState();
      sink.emitEndedState();

      expect(states, isEmpty);
    });

    test('forwards non-state events without lifecycle filtering', () {
      final aiTexts = <String>[];
      final transcripts = <TranscriptEntry>[];
      final errors = <String>[];
      final sink = _buildSink(
        aiTexts: aiTexts,
        transcripts: transcripts,
        errors: errors,
      );
      const transcript = TranscriptEntry(role: 'assistant', text: 'こんにちは');

      sink.emitAiTextDelta('やっほー');
      sink.emitTranscriptEntry(transcript);
      sink.emitError('boom');

      expect(aiTexts, ['やっほー']);
      expect(transcripts, [transcript]);
      expect(errors, ['boom']);
    });
  });
}

GeminiLiveSessionEventSink _buildSink({
  GeminiLiveLifecycleController? lifecycleController,
  List<GeminiLiveState>? states,
  List<String>? aiTexts,
  List<TranscriptEntry>? transcripts,
  List<String>? errors,
}) {
  return GeminiLiveSessionEventSink(
    lifecycleController: lifecycleController ?? GeminiLiveLifecycleController(),
    emitState: (state) => states?.add(state),
    emitAiTextDelta: (text) => aiTexts?.add(text),
    emitTranscriptEntry: (entry) => transcripts?.add(entry),
    emitError: (message) => errors?.add(message),
  );
}
