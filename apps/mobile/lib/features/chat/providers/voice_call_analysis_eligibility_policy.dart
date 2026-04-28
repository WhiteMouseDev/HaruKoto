import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gemini_live_service.dart';
import 'voice_call_connection_service.dart';

final voiceCallAnalysisEligibilityPolicyProvider =
    Provider<VoiceCallAnalysisEligibilityPolicy>(
  (ref) => const VoiceCallAnalysisEligibilityPolicy(),
);

class VoiceCallAnalysisEligibilityPolicy {
  const VoiceCallAnalysisEligibilityPolicy({
    this.minimumDurationSeconds = 15,
  });

  final int minimumDurationSeconds;

  bool allows({
    required VoiceCallSessionRequest? request,
    required List<TranscriptEntry> transcript,
    required int durationSeconds,
    required bool autoAnalysis,
  }) {
    final hasUserTranscript = transcript.any(
      (entry) => entry.role == 'user' && entry.text.trim().isNotEmpty,
    );

    return request != null &&
        autoAnalysis &&
        durationSeconds >= minimumDurationSeconds &&
        hasUserTranscript;
  }
}
