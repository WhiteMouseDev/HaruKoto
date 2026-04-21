import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_service.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_live_session_starter.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_resources.dart';

void main() {
  group('VoiceCallLiveSessionStarter', () {
    test('attaches service, binds callbacks, and starts the live service',
        () async {
      final service = _FakeGeminiLiveService();
      final resources =
          VoiceCallSessionResources(_FakeVoiceCallRingtonePlayer());
      final states = <GeminiLiveState>[];
      final textDeltas = <String>[];
      final transcripts = <TranscriptEntry>[];
      final errors = <String>[];

      final result = await const VoiceCallLiveSessionStarter().start(
        VoiceCallLiveSessionStartInput(
          service: service,
          resources: resources,
          isActive: () => true,
          callbacks: VoiceCallLiveSessionCallbacks(
            onStateChange: states.add,
            onAiTextDelta: textDeltas.add,
            onTranscriptEntry: transcripts.add,
            onError: errors.add,
          ),
        ),
      );

      service.emitAiText('こんにちは');
      service.emitTranscriptEntry(
        const TranscriptEntry(role: 'assistant', text: 'こんにちは'),
      );
      service.emitError('network error');

      expect(result.hasError, isFalse);
      expect(result.stale, isFalse);
      expect(resources.service, service);
      expect(service.startCalls, 1);
      expect(states, [GeminiLiveState.connected]);
      expect(textDeltas, ['こんにちは']);
      expect(transcripts, [
        const TranscriptEntry(role: 'assistant', text: 'こんにちは'),
      ]);
      expect(errors, ['network error']);
    });

    test('returns failure and stops ringtone when live service start throws',
        () async {
      final service = _FakeGeminiLiveService(startError: 'boom');
      final ringtone = _FakeVoiceCallRingtonePlayer();
      final resources = VoiceCallSessionResources(ringtone);

      final result = await const VoiceCallLiveSessionStarter().start(
        VoiceCallLiveSessionStartInput(
          service: service,
          resources: resources,
          isActive: () => true,
          callbacks: VoiceCallLiveSessionCallbacks(
            onStateChange: (_) {},
            onAiTextDelta: (_) {},
            onTranscriptEntry: (_) {},
            onError: (_) {},
          ),
        ),
      );

      expect(result.hasError, isTrue);
      expect(result.errorMessage, contains('연결에 실패했습니다'));
      expect(result.stale, isFalse);
      expect(ringtone.stopCalls, 1);
    });

    test('returns stale when live service start throws after becoming inactive',
        () async {
      final service = _FakeGeminiLiveService(startError: 'boom');
      final ringtone = _FakeVoiceCallRingtonePlayer();
      final resources = VoiceCallSessionResources(ringtone);

      final result = await const VoiceCallLiveSessionStarter().start(
        VoiceCallLiveSessionStartInput(
          service: service,
          resources: resources,
          isActive: () => false,
          callbacks: VoiceCallLiveSessionCallbacks(
            onStateChange: (_) {},
            onAiTextDelta: (_) {},
            onTranscriptEntry: (_) {},
            onError: (_) {},
          ),
        ),
      );

      expect(result.stale, isTrue);
      expect(result.hasError, isFalse);
      expect(ringtone.stopCalls, 0);
    });
  });
}

class _FakeGeminiLiveService extends GeminiLiveService {
  _FakeGeminiLiveService({this.startError})
      : super(
          wsUri: 'wss://example.com/live',
          token: 'token',
          model: 'gemini-live',
        );

  final String? startError;
  int startCalls = 0;

  @override
  Future<void> start() async {
    startCalls++;
    final error = startError;
    if (error != null) {
      throw StateError(error);
    }
    onStateChange?.call(GeminiLiveState.connected);
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

class _FakeVoiceCallRingtonePlayer implements VoiceCallRingtonePlayer {
  int stopCalls = 0;

  @override
  Future<void> startLoop() async {}

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> dispose() async {}
}
