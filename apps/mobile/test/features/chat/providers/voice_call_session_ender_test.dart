import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_service.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_ender.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_resources.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_timer.dart';

void main() {
  group('VoiceCallSessionEnder', () {
    testWidgets('a stalled shutdown saves without disposing a newer service',
        (tester) async {
      final stopped = Completer<void>();
      final oldService = _FakeGeminiLiveService()
        ..providedTranscript = const [
          TranscriptEntry(role: 'user', text: '予約です')
        ]
        ..ending = stopped.future;
      final newService = _FakeGeminiLiveService();
      final resources =
          VoiceCallSessionResources(_FakeVoiceCallRingtonePlayer())
            ..attachService(oldService);
      final ending = const VoiceCallSessionEnder().end(resources);
      await tester.pump();
      resources.attachService(newService);
      await tester.pump(const Duration(seconds: 3));

      final result = await ending;
      expect(result.transcript.single.text, '予約です');
      expect(oldService.disposeCalls, 1);
      expect(newService.disposeCalls, 0);
      stopped.completeError(StateError('late native stop error'));
      await tester.pump();
      expect(newService.endCalls, 0);
      expect(resources.service, same(newService));
    });

    test('keeps captured transcript when native shutdown fails', () async {
      final service = _FakeGeminiLiveService()
        ..providedTranscript = const [TranscriptEntry(role: 'user', text: 'はい')]
        ..endFailure = StateError('native stop failed');
      final resources =
          VoiceCallSessionResources(_FakeVoiceCallRingtonePlayer())
            ..attachService(service);

      final result = await const VoiceCallSessionEnder().end(resources);
      await Future<void>.delayed(Duration.zero);

      expect(result.transcript.single.text, 'はい');
      expect(service.disposeCalls, 1);
    });

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
  int disposeCalls = 0;
  Object? endFailure;
  Future<void>? ending;
  List<TranscriptEntry> providedTranscript = const [];

  @override
  List<TranscriptEntry> get transcript => List.unmodifiable(providedTranscript);

  @override
  Future<void> end() async {
    endCalls++;
    if (endFailure != null) throw endFailure!;
    await ending;
  }

  @override
  Future<void> dispose() async => disposeCalls++;
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
