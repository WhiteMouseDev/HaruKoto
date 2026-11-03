import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_service.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_live_event_binder.dart';

void main() {
  group('VoiceCallLiveEventBinder', () {
    test('forwards live service events while active', () {
      final service = _FakeGeminiLiveService();
      final states = <GeminiLiveState>[];
      final textDeltas = <String>[];
      final transcripts = <TranscriptEntry>[];
      final errors = <String>[];
      var microphoneInterruptions = 0;

      VoiceCallLiveEventBinder(
        service: service,
        isActive: () => true,
        onStateChange: states.add,
        onAiTextDelta: textDeltas.add,
        onTranscriptEntry: transcripts.add,
        onError: errors.add,
        onMicrophoneInterrupted: () => microphoneInterruptions++,
      ).bind();

      service.emitState(GeminiLiveState.connected);
      service.emitAiText('こんにちは');
      service.emitTranscriptEntry(
        const TranscriptEntry(role: 'assistant', text: 'こんにちは'),
      );
      service.emitError('network error');
      service.onMicrophoneInterrupted?.call();

      expect(states, [GeminiLiveState.connected]);
      expect(textDeltas, ['こんにちは']);
      expect(transcripts, [
        const TranscriptEntry(role: 'assistant', text: 'こんにちは'),
      ]);
      expect(errors, ['network error']);
      expect(microphoneInterruptions, 1);
    });

    test('ignores live service events while inactive', () {
      final service = _FakeGeminiLiveService();
      var calls = 0;

      VoiceCallLiveEventBinder(
        service: service,
        isActive: () => false,
        onStateChange: (_) => calls++,
        onAiTextDelta: (_) => calls++,
        onTranscriptEntry: (_) => calls++,
        onError: (_) => calls++,
        onMicrophoneInterrupted: () => calls++,
      ).bind();

      service.emitState(GeminiLiveState.connected);
      service.emitAiText('こんにちは');
      service.emitTranscriptEntry(
        const TranscriptEntry(role: 'assistant', text: 'こんにちは'),
      );
      service.emitError('network error');
      service.onMicrophoneInterrupted?.call();

      expect(calls, 0);
    });
  });
}

class _FakeGeminiLiveService extends GeminiLiveService {
  _FakeGeminiLiveService()
      : super(
          wsUri: 'wss://example.com/live',
          token: 'token',
          model: 'gemini-live',
        );

  void emitState(GeminiLiveState state) {
    onStateChange?.call(state);
  }

  void emitAiText(String text) {
    onAiTextDelta?.call(text);
  }

  void emitTranscriptEntry(TranscriptEntry entry) {
    onTranscriptEntry?.call(entry);
  }

  void emitError(String message) {
    onError?.call(message);
  }
}
