import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_service.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_resources.dart';

void main() {
  group('VoiceCallSessionResources', () {
    test('play and stop delegate to the ringtone player', () async {
      final ringtone = _FakeVoiceCallRingtonePlayer();
      final resources = VoiceCallSessionResources(ringtone);

      await resources.playRingtone();
      await resources.stopRingtone();

      expect(ringtone.startCalls, 1);
      expect(ringtone.stopCalls, 1);
    });

    test('cancelActiveSession stops timer, ringtone, and disposes service',
        () async {
      final ringtone = _FakeVoiceCallRingtonePlayer();
      final service = _FakeGeminiLiveService();
      final resources = VoiceCallSessionResources(ringtone);
      var tickCount = 0;

      resources.attachService(service);
      resources.startTimer(() => tickCount++);
      await resources.cancelActiveSession();

      expect(resources.service, isNull);
      expect(ringtone.stopCalls, 1);
      expect(service.disposed, isTrue);
      expect(tickCount, 0);
    });

    test('endService delegates to the attached live service', () async {
      final resources =
          VoiceCallSessionResources(_FakeVoiceCallRingtonePlayer());
      final service = _FakeGeminiLiveService();

      resources.attachService(service);
      await resources.endService();

      expect(service.endCalls, 1);
    });

    test('dispose cancels session and disposes ringtone', () async {
      final ringtone = _FakeVoiceCallRingtonePlayer();
      final service = _FakeGeminiLiveService();
      final resources = VoiceCallSessionResources(ringtone);

      resources.attachService(service);
      await resources.dispose();

      expect(service.disposed, isTrue);
      expect(ringtone.disposed, isTrue);
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
  bool disposed = false;

  @override
  Future<void> end() async {
    endCalls++;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class _FakeVoiceCallRingtonePlayer implements VoiceCallRingtonePlayer {
  int startCalls = 0;
  int stopCalls = 0;
  bool disposed = false;

  @override
  Future<void> startLoop() async {
    startCalls++;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}
