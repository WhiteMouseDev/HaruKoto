import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_service.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_analysis_request_factory.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_connection_service.dart';

void main() {
  group('VoiceCallAnalysisRequestFactory', () {
    const factory = VoiceCallAnalysisRequestFactory();
    const request = VoiceCallSessionRequest(
      scenarioId: 'scenario-1',
      characterId: 'char-1',
      characterName: '하루',
    );
    const transcript = [
      TranscriptEntry(role: 'user', text: 'もしもし'),
      TranscriptEntry(role: 'assistant', text: 'やっほー'),
    ];

    test('build returns an analysis request when call qualifies', () {
      final result = factory.build(
        const VoiceCallAnalysisRequestInput(
          request: request,
          transcript: transcript,
          durationSeconds: 20,
          autoAnalysis: true,
        ),
      );

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

    test('build returns null when auto analysis is disabled', () {
      final result = factory.build(
        const VoiceCallAnalysisRequestInput(
          request: request,
          transcript: transcript,
          durationSeconds: 20,
          autoAnalysis: false,
        ),
      );

      expect(result, isNull);
    });

    test('build returns null when duration is too short', () {
      final result = factory.build(
        const VoiceCallAnalysisRequestInput(
          request: request,
          transcript: transcript,
          durationSeconds: 14,
          autoAnalysis: true,
        ),
      );

      expect(result, isNull);
    });

    test('build returns null when transcript is empty', () {
      final result = factory.build(
        const VoiceCallAnalysisRequestInput(
          request: request,
          transcript: [],
          durationSeconds: 20,
          autoAnalysis: true,
        ),
      );

      expect(result, isNull);
    });
  });
}
