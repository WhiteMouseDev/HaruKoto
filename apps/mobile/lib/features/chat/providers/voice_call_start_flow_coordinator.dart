import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gemini_live_service.dart';
import 'voice_call_connection_service.dart';
import 'voice_call_session_resources.dart';
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
    this.stale = false,
  });

  const VoiceCallStartFlowResult.ready(GeminiLiveService service)
      : this._(service: service);

  const VoiceCallStartFlowResult.failure(String message)
      : this._(errorMessage: message);

  const VoiceCallStartFlowResult.stale() : this._(stale: true);

  final GeminiLiveService? service;
  final String? errorMessage;
  final bool stale;

  bool get hasError => errorMessage != null;
}

class VoiceCallStartFlowCoordinator {
  VoiceCallStartFlowCoordinator({
    required VoiceCallStartContextReader startContextReader,
    required VoiceCallConnectionService connectionService,
    VoiceCallStartPreparationStep? preparationStep,
  })  : _preparationStep = preparationStep ??
            VoiceCallStartPreparationStep(
              startContextReader: startContextReader,
            ),
        _connectionService = connectionService;

  final VoiceCallStartPreparationStep _preparationStep;
  final VoiceCallConnectionService _connectionService;

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

    try {
      final service = await _connectionService.prepare(
        startContext.toConnectionInput(input.request),
      );
      if (input.isStale()) {
        await service.dispose();
        return const VoiceCallStartFlowResult.stale();
      }

      return VoiceCallStartFlowResult.ready(service);
    } on VoiceCallConnectionException catch (e) {
      if (input.isStale()) return const VoiceCallStartFlowResult.stale();
      await input.resources?.stopRingtone();
      return VoiceCallStartFlowResult.failure(e.message);
    } catch (e) {
      debugPrint('[VoiceCallSession] Start failed: $e');
      if (input.isStale()) return const VoiceCallStartFlowResult.stale();
      await input.resources?.stopRingtone();
      return VoiceCallStartFlowResult.failure('연결에 실패했습니다: $e');
    }
  }
}
