import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gemini_live_service.dart';
import 'voice_call_connection_service.dart';
import 'voice_call_session_resources.dart';
import 'voice_call_start_connection_step.dart';
import 'voice_call_start_context_reader.dart';
import 'voice_call_start_preparation_step.dart';

final voiceCallStartFlowCoordinatorProvider =
    Provider<VoiceCallStartFlowCoordinator>((ref) {
  return VoiceCallStartFlowCoordinator(
    startContextReader: ref.watch(voiceCallStartContextReaderProvider),
    connectionService: ref.watch(voiceCallConnectionServiceProvider),
  );
});

class VoiceCallStartFlowInput {
  const VoiceCallStartFlowInput({
    required this.request,
    required this.resources,
    required this.isStale,
    required this.setState,
  });

  final VoiceCallSessionRequest request;
  final VoiceCallSessionResources? resources;
  final VoiceCallStaleCheck isStale;
  final VoiceCallStateSetter setState;
}

class VoiceCallStartFlowResult {
  const VoiceCallStartFlowResult._({
    this.service,
    this.errorMessage,
    this.canRetry = true,
    this.stale = false,
  });

  const VoiceCallStartFlowResult.ready(GeminiLiveService service)
      : this._(service: service);

  const VoiceCallStartFlowResult.failure(
    String message, {
    bool canRetry = true,
  }) : this._(errorMessage: message, canRetry: canRetry);

  const VoiceCallStartFlowResult.stale() : this._(stale: true);

  final GeminiLiveService? service;
  final String? errorMessage;
  final bool canRetry;
  final bool stale;

  bool get hasError => errorMessage != null;
}

class VoiceCallStartFlowCoordinator {
  VoiceCallStartFlowCoordinator({
    required VoiceCallStartContextReader startContextReader,
    required VoiceCallConnectionService connectionService,
    VoiceCallStartPreparationStep? preparationStep,
    VoiceCallStartConnectionStep? connectionStep,
  })  : _preparationStep = preparationStep ??
            VoiceCallStartPreparationStep(
              startContextReader: startContextReader,
            ),
        _connectionStep = connectionStep ??
            VoiceCallStartConnectionStep(
              connectionService: connectionService,
            );

  final VoiceCallStartPreparationStep _preparationStep;
  final VoiceCallStartConnectionStep _connectionStep;

  Future<VoiceCallStartFlowResult> prepare(
    VoiceCallStartFlowInput input,
  ) async {
    final preparation = await _preparationStep.prepare(
      VoiceCallStartPreparationInput(
        resources: input.resources,
        isStale: input.isStale,
        setState: input.setState,
      ),
    );
    final startContext = preparation.context;
    if (preparation.stale || startContext == null) {
      return const VoiceCallStartFlowResult.stale();
    }

    final connection = await _connectionStep.connect(
      VoiceCallStartConnectionInput(
        request: input.request,
        startContext: startContext,
        resources: input.resources,
        isStale: input.isStale,
      ),
    );
    if (connection.stale) {
      return const VoiceCallStartFlowResult.stale();
    }
    final errorMessage = connection.errorMessage;
    if (errorMessage != null) {
      return VoiceCallStartFlowResult.failure(
        errorMessage,
        canRetry: connection.canRetry,
      );
    }
    final service = connection.service;
    if (service == null) return const VoiceCallStartFlowResult.stale();

    return VoiceCallStartFlowResult.ready(service);
  }
}
