import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gemini_live_service.dart';
import 'voice_call_analysis_eligibility_policy.dart';
import 'voice_call_connection_service.dart';

class VoiceCallAnalysisRequest {
  const VoiceCallAnalysisRequest({
    required this.transcript,
    required this.durationSeconds,
    this.analysisEnabled = true,
    this.recordSaved = false,
    this.wasConnected = true,
    this.conversationId,
    this.characterId,
    this.characterName,
    this.scenarioId,
  });

  final List<Map<String, String>> transcript;
  final int durationSeconds;
  final bool analysisEnabled;
  final bool recordSaved;
  final bool wasConnected;
  final String? conversationId;
  final String? characterId;
  final String? characterName;
  final String? scenarioId;

  VoiceCallAnalysisRequest withConversationId(String id) =>
      VoiceCallAnalysisRequest(
        transcript: transcript,
        durationSeconds: durationSeconds,
        analysisEnabled: analysisEnabled,
        conversationId: id,
        recordSaved: true,
        wasConnected: wasConnected,
        characterId: characterId,
        characterName: characterName,
        scenarioId: scenarioId,
      );
  VoiceCallAnalysisRequest requestAnalysis() => VoiceCallAnalysisRequest(
        transcript: transcript,
        durationSeconds: durationSeconds,
        conversationId: conversationId,
        recordSaved: recordSaved,
        wasConnected: wasConnected,
        analysisEnabled: true,
        characterId: characterId,
        characterName: characterName,
        scenarioId: scenarioId,
      );
}

class VoiceCallAnalysisRequestInput {
  const VoiceCallAnalysisRequestInput({
    required this.request,
    required this.transcript,
    required this.durationSeconds,
    required this.autoAnalysis,
    this.wasConnected = true,
  });

  final VoiceCallSessionRequest? request;
  final List<TranscriptEntry> transcript;
  final int durationSeconds;
  final bool autoAnalysis;
  final bool wasConnected;
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
    if (request == null) return null;
    final analysisEnabled = _eligibilityPolicy.allows(
      request: request,
      transcript: input.transcript,
      durationSeconds: input.durationSeconds,
      autoAnalysis: input.autoAnalysis,
    );

    return VoiceCallAnalysisRequest(
      transcript: input.transcript.map((entry) => entry.toJson()).toList(),
      durationSeconds: input.durationSeconds,
      analysisEnabled: analysisEnabled,
      wasConnected: input.wasConnected,
      conversationId: request.conversationId,
      characterId: request.characterId,
      characterName: request.characterName,
      scenarioId: request.scenarioId,
    );
  }
}
