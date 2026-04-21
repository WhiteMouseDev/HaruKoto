import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gemini_live_service.dart';
import 'voice_call_analysis_eligibility_policy.dart';
import 'voice_call_connection_service.dart';

class VoiceCallAnalysisRequest {
  const VoiceCallAnalysisRequest({
    required this.transcript,
    required this.durationSeconds,
    this.characterId,
    this.characterName,
    this.scenarioId,
  });

  final List<Map<String, String>> transcript;
  final int durationSeconds;
  final String? characterId;
  final String? characterName;
  final String? scenarioId;
}

class VoiceCallAnalysisRequestInput {
  const VoiceCallAnalysisRequestInput({
    required this.request,
    required this.transcript,
    required this.durationSeconds,
    required this.autoAnalysis,
  });

  final VoiceCallSessionRequest? request;
  final List<TranscriptEntry> transcript;
  final int durationSeconds;
  final bool autoAnalysis;
}

final voiceCallAnalysisRequestFactoryProvider =
    Provider<VoiceCallAnalysisRequestFactory>(
  (ref) => VoiceCallAnalysisRequestFactory(
    eligibilityPolicy: ref.watch(voiceCallAnalysisEligibilityPolicyProvider),
  ),
);

class VoiceCallAnalysisRequestFactory {
  const VoiceCallAnalysisRequestFactory({
    VoiceCallAnalysisEligibilityPolicy eligibilityPolicy =
        const VoiceCallAnalysisEligibilityPolicy(),
  }) : _eligibilityPolicy = eligibilityPolicy;

  final VoiceCallAnalysisEligibilityPolicy _eligibilityPolicy;

  VoiceCallAnalysisRequest? build(VoiceCallAnalysisRequestInput input) {
    final request = input.request;
    if (!_eligibilityPolicy.allows(
          request: request,
          transcript: input.transcript,
          durationSeconds: input.durationSeconds,
          autoAnalysis: input.autoAnalysis,
        ) ||
        request == null) {
      return null;
    }

    return VoiceCallAnalysisRequest(
      transcript: input.transcript.map((entry) => entry.toJson()).toList(),
      durationSeconds: input.durationSeconds,
      characterId: request.characterId,
      characterName: request.characterName,
      scenarioId: request.scenarioId,
    );
  }
}
