import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/user_preferences_provider.dart';
import 'voice_call_analysis_request_factory.dart';
import 'voice_call_connection_service.dart';
import 'voice_call_session_resources.dart';
import 'voice_call_session_ender.dart';

typedef VoiceCallAutoAnalysisReader = bool Function();

final voiceCallEndFlowCoordinatorProvider =
    Provider<VoiceCallEndFlowCoordinator>((ref) {
  return VoiceCallEndFlowCoordinator(
    analysisRequestFactory: ref.watch(voiceCallAnalysisRequestFactoryProvider),
    sessionEnder: ref.watch(voiceCallSessionEnderProvider),
    readAutoAnalysis: () =>
        ref.read(userPreferencesProvider).callSettings.autoAnalysis,
  );
});

class VoiceCallEndFlowInput {
  const VoiceCallEndFlowInput({
    required this.resources,
    required this.request,
    required this.durationSeconds,
    required this.wasConnected,
  });

  final VoiceCallSessionResources? resources;
  final VoiceCallSessionRequest? request;
  final int durationSeconds;
  final bool wasConnected;
}

class VoiceCallEndFlowResult {
  const VoiceCallEndFlowResult({
    this.analysisRequest,
    this.feedbackError,
  });

  final VoiceCallAnalysisRequest? analysisRequest;
  final String? feedbackError;
}

class VoiceCallEndFlowCoordinator {
  const VoiceCallEndFlowCoordinator({
    required VoiceCallAnalysisRequestFactory analysisRequestFactory,
    required VoiceCallSessionEnder sessionEnder,
    required VoiceCallAutoAnalysisReader readAutoAnalysis,
  })  : _analysisRequestFactory = analysisRequestFactory,
        _sessionEnder = sessionEnder,
        _readAutoAnalysis = readAutoAnalysis;

  final VoiceCallAnalysisRequestFactory _analysisRequestFactory;
  final VoiceCallSessionEnder _sessionEnder;
  final VoiceCallAutoAnalysisReader _readAutoAnalysis;

  Future<VoiceCallEndFlowResult> end(VoiceCallEndFlowInput input) async {
    final endedSession = await _sessionEnder.end(input.resources);
    if (!input.wasConnected) {
      return const VoiceCallEndFlowResult();
    }

    final autoAnalysis = _readAutoAnalysis();

    final analysisRequest = _analysisRequestFactory.build(
      VoiceCallAnalysisRequestInput(
        request: input.request,
        transcript: endedSession.transcript,
        durationSeconds: input.durationSeconds,
        autoAnalysis: autoAnalysis,
      ),
    );

    if (analysisRequest != null) {
      return VoiceCallEndFlowResult(analysisRequest: analysisRequest);
    }

    if (input.request != null && autoAnalysis) {
      return const VoiceCallEndFlowResult(feedbackError: 'no_transcript');
    }

    return const VoiceCallEndFlowResult();
  }
}
