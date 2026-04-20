import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gemini_live_service.dart';
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
  (ref) => const VoiceCallAnalysisRequestFactory(),
);

class VoiceCallAnalysisRequestFactory {
  const VoiceCallAnalysisRequestFactory();

  VoiceCallAnalysisRequest? build(VoiceCallAnalysisRequestInput input) {
    final request = input.request;
    if (request == null ||
        !input.autoAnalysis ||
        input.durationSeconds < 15 ||
        input.transcript.isEmpty) {
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
