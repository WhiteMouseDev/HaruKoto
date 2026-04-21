import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_service.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_ender.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_resources.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_timer.dart';

void main() {
  group('VoiceCallSessionEnder', () {
    test('stops timer, snapshots transcript, and ends service', () async {
      final timer = _FakeVoiceCallSessionTimer();
      final service = _FakeGeminiLiveService()
        ..providedTranscript = const [
          TranscriptEntry(role: 'user', text: 'もしもし'),
          TranscriptEntry(role: 'assistant', text: 'やっほー'),
        ];
      final resources = VoiceCallSessionResources(
        _FakeVoiceCallRingtonePlayer(),
        timer: timer,
      )..attachService(service);
      const ender = VoiceCallSessionEnder();

      final result = await ender.end(resources);

      expect(timer.stopCalls, 1);
      expect(service.endCalls, 1);
      expect(result.transcript, service.providedTranscript);
    });

    test('returns an empty transcript when resources are missing', () async {
      const ender = VoiceCallSessionEnder();

      final result = await ender.end(null);

      expect(result.transcript, isEmpty);
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

  int endCalls = 0;
  List<TranscriptEntry> providedTranscript = const [];

  @override
  List<TranscriptEntry> get transcript => List.unmodifiable(providedTranscript);

  @override
  Future<void> end() async {
    endCalls++;
  }
}

class _FakeVoiceCallRingtonePlayer implements VoiceCallRingtonePlayer {
  @override
  Future<void> startLoop() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class _FakeVoiceCallSessionTimer implements VoiceCallSessionTimer {
  int stopCalls = 0;

  @override
  void start(void Function() onTick) {}

  @override
  void stop() {
    stopCalls++;
  }

  @override
  void dispose() {}
}
