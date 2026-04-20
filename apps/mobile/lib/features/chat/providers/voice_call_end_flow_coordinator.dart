import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/user_preferences_provider.dart';
import '../data/gemini_live_service.dart';
import 'voice_call_analysis_request_factory.dart';
import 'voice_call_connection_service.dart';
import 'voice_call_session_resources.dart';

typedef VoiceCallAutoAnalysisReader = bool Function();

final voiceCallEndFlowCoordinatorProvider =
    Provider<VoiceCallEndFlowCoordinator>((ref) {
  return VoiceCallEndFlowCoordinator(
    analysisRequestFactory: ref.watch(voiceCallAnalysisRequestFactoryProvider),
    readAutoAnalysis: () =>
        ref.read(userPreferencesProvider).callSettings.autoAnalysis,
  );
});

class VoiceCallEndFlowInput {
  const VoiceCallEndFlowInput({
    required this.resources,
    required this.request,
    required this.durationSeconds,
  });

  final VoiceCallSessionResources? resources;
  final VoiceCallSessionRequest? request;
  final int durationSeconds;
}

class VoiceCallEndFlowCoordinator {
  const VoiceCallEndFlowCoordinator({
    required VoiceCallAnalysisRequestFactory analysisRequestFactory,
    required VoiceCallAutoAnalysisReader readAutoAnalysis,
  })  : _analysisRequestFactory = analysisRequestFactory,
        _readAutoAnalysis = readAutoAnalysis;

  final VoiceCallAnalysisRequestFactory _analysisRequestFactory;
  final VoiceCallAutoAnalysisReader _readAutoAnalysis;

  Future<VoiceCallAnalysisRequest?> end(VoiceCallEndFlowInput input) async {
    final resources = input.resources;
    resources?.stopTimer();

    final transcript = resources?.transcript ?? const <TranscriptEntry>[];
    await resources?.endService();

    return _analysisRequestFactory.build(
      VoiceCallAnalysisRequestInput(
        request: input.request,
        transcript: transcript,
        durationSeconds: input.durationSeconds,
        autoAnalysis: _readAutoAnalysis(),
      ),
    );
  }
}
