import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'voice_call_analysis_request_factory.dart';
import 'voice_call_connection_service.dart';
import 'voice_call_end_flow_coordinator.dart';
import 'voice_call_session_resources.dart';

typedef VoiceCallEndFlowRunner = Future<VoiceCallEndFlowResult> Function(
  VoiceCallEndFlowInput input,
);

final voiceCallEndCallHandlerProvider = Provider<VoiceCallEndCallHandler>(
  (ref) => VoiceCallEndCallHandler(
    endFlow: ref.watch(voiceCallEndFlowCoordinatorProvider).end,
  ),
);

class VoiceCallEndCallInput {
  const VoiceCallEndCallInput({
    required this.resources,
    required this.request,
    required this.durationSeconds,
  });

  final VoiceCallSessionResources? resources;
  final VoiceCallSessionRequest? request;
  final int durationSeconds;
}

class VoiceCallEndResult {
  const VoiceCallEndResult({
    this.analysisRequest,
    this.feedbackError,
    this.ignored = false,
  });

  final VoiceCallAnalysisRequest? analysisRequest;
  final String? feedbackError;
  final bool ignored;
}

class VoiceCallEndCallHandler {
  VoiceCallEndCallHandler({
    required VoiceCallEndFlowRunner endFlow,
  }) : _endFlow = endFlow;

  final VoiceCallEndFlowRunner _endFlow;
  bool _isEnding = false;

  void reset() {
    _isEnding = false;
  }

  Future<VoiceCallEndResult> end(VoiceCallEndCallInput input) async {
    if (_isEnding) {
      return const VoiceCallEndResult(ignored: true);
    }

    _isEnding = true;
    final flowResult = await _endFlow(
      VoiceCallEndFlowInput(
        resources: input.resources,
        request: input.request,
        durationSeconds: input.durationSeconds,
      ),
    );

    return VoiceCallEndResult(
      analysisRequest: flowResult.analysisRequest,
      feedbackError: flowResult.feedbackError,
    );
  }
}
