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
    return request != null &&
        autoAnalysis &&
        durationSeconds >= minimumDurationSeconds &&
        transcript.isNotEmpty;
  }
}
