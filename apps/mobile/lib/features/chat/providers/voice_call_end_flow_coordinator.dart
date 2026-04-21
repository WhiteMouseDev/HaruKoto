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
  });

  final VoiceCallSessionResources? resources;
  final VoiceCallSessionRequest? request;
  final int durationSeconds;
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

  Future<VoiceCallAnalysisRequest?> end(VoiceCallEndFlowInput input) async {
    final endedSession = await _sessionEnder.end(input.resources);

    return _analysisRequestFactory.build(
      VoiceCallAnalysisRequestInput(
        request: input.request,
        transcript: endedSession.transcript,
        durationSeconds: input.durationSeconds,
        autoAnalysis: _readAutoAnalysis(),
      ),
    );
  }
}
