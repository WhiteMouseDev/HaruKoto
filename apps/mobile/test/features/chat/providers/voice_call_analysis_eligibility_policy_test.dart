import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_service.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_analysis_eligibility_policy.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_connection_service.dart';

void main() {
  group('VoiceCallAnalysisEligibilityPolicy', () {
    const request = VoiceCallSessionRequest(characterId: 'char-1');
    const transcript = [
      TranscriptEntry(role: 'user', text: 'もしもし'),
    ];

    test(
        'allows analysis when request, settings, duration, and transcript pass',
        () {
      const policy = VoiceCallAnalysisEligibilityPolicy();

      final result = policy.allows(
        request: request,
        transcript: transcript,
        durationSeconds: 15,
        autoAnalysis: true,
      );

      expect(result, isTrue);
    });

    test('rejects calls without a request', () {
      const policy = VoiceCallAnalysisEligibilityPolicy();

      final result = policy.allows(
        request: null,
        transcript: transcript,
        durationSeconds: 20,
        autoAnalysis: true,
      );

      expect(result, isFalse);
    });

    test('rejects calls when auto analysis is disabled', () {
      const policy = VoiceCallAnalysisEligibilityPolicy();

      final result = policy.allows(
        request: request,
        transcript: transcript,
        durationSeconds: 20,
        autoAnalysis: false,
      );

      expect(result, isFalse);
    });

    test('rejects calls below the minimum duration', () {
      const policy = VoiceCallAnalysisEligibilityPolicy();

      final result = policy.allows(
        request: request,
        transcript: transcript,
        durationSeconds: 14,
        autoAnalysis: true,
      );

      expect(result, isFalse);
    });

    test('rejects calls without transcript entries', () {
      const policy = VoiceCallAnalysisEligibilityPolicy();

      final result = policy.allows(
        request: request,
        transcript: const [],
        durationSeconds: 20,
        autoAnalysis: true,
      );

      expect(result, isFalse);
    });

    test('rejects calls without a user transcript entry', () {
      const policy = VoiceCallAnalysisEligibilityPolicy();

      final result = policy.allows(
        request: request,
        transcript: const [
          TranscriptEntry(role: 'assistant', text: 'もしもし'),
        ],
        durationSeconds: 20,
        autoAnalysis: true,
      );

      expect(result, isFalse);
    });

    test('rejects calls with only blank user transcript entries', () {
      const policy = VoiceCallAnalysisEligibilityPolicy();

      final result = policy.allows(
        request: request,
        transcript: const [
          TranscriptEntry(role: 'assistant', text: 'もしもし'),
          TranscriptEntry(role: 'user', text: '  '),
        ],
        durationSeconds: 20,
        autoAnalysis: true,
      );

      expect(result, isFalse);
    });

    test('uses the configured minimum duration', () {
      const policy = VoiceCallAnalysisEligibilityPolicy(
        minimumDurationSeconds: 30,
      );

      expect(
        policy.allows(
          request: request,
          transcript: transcript,
          durationSeconds: 29,
          autoAnalysis: true,
        ),
        isFalse,
      );
      expect(
        policy.allows(
          request: request,
          transcript: transcript,
          durationSeconds: 30,
          autoAnalysis: true,
        ),
        isTrue,
      );
    });
  });
}
