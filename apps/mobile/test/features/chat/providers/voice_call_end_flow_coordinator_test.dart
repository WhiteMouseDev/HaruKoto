import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_service.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_analysis_request_factory.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_connection_service.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_end_flow_coordinator.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_resources.dart';

void main() {
  group('VoiceCallEndFlowCoordinator', () {
    test('ends resources and builds an analysis request when eligible',
        () async {
      final service = _FakeGeminiLiveService()
        ..providedTranscript = const [
          TranscriptEntry(role: 'user', text: 'もしもし'),
          TranscriptEntry(role: 'assistant', text: 'やっほー'),
        ];
      final resources =
          VoiceCallSessionResources(_FakeVoiceCallRingtonePlayer())
            ..attachService(service);
      final coordinator = VoiceCallEndFlowCoordinator(
        analysisRequestFactory: const VoiceCallAnalysisRequestFactory(),
        readAutoAnalysis: () => true,
      );

      final result = await coordinator.end(
        VoiceCallEndFlowInput(
          resources: resources,
          request: const VoiceCallSessionRequest(
            scenarioId: 'scenario-1',
            characterId: 'char-1',
            characterName: '하루',
          ),
          durationSeconds: 20,
        ),
      );

      expect(service.endCalls, 1);
      expect(result, isNotNull);
      expect(result!.durationSeconds, 20);
      expect(result.characterId, 'char-1');
      expect(result.characterName, '하루');
      expect(result.scenarioId, 'scenario-1');
      expect(result.transcript, [
        {'role': 'user', 'text': 'もしもし'},
        {'role': 'assistant', 'text': 'やっほー'},
      ]);
    });

    test('still ends resources when auto analysis is disabled', () async {
      final service = _FakeGeminiLiveService()
        ..providedTranscript = const [
          TranscriptEntry(role: 'user', text: 'もしもし'),
        ];
      final resources =
          VoiceCallSessionResources(_FakeVoiceCallRingtonePlayer())
            ..attachService(service);
      final coordinator = VoiceCallEndFlowCoordinator(
        analysisRequestFactory: const VoiceCallAnalysisRequestFactory(),
        readAutoAnalysis: () => false,
      );

      final result = await coordinator.end(
        VoiceCallEndFlowInput(
          resources: resources,
          request: const VoiceCallSessionRequest(characterId: 'char-1'),
          durationSeconds: 20,
        ),
      );

      expect(service.endCalls, 1);
      expect(result, isNull);
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
