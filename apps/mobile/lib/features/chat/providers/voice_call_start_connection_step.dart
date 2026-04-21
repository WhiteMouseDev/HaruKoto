import 'package:flutter/foundation.dart';

import '../data/gemini_live_service.dart';
import 'voice_call_connection_service.dart';
import 'voice_call_session_resources.dart';
import 'voice_call_start_context_reader.dart';
import 'voice_call_start_preparation_step.dart';

class VoiceCallStartConnectionInput {
  const VoiceCallStartConnectionInput({
    required this.request,
    required this.startContext,
    required this.resources,
    required this.isStale,
  });

  final VoiceCallSessionRequest request;
  final VoiceCallStartContext startContext;
  final VoiceCallSessionResources? resources;
  final VoiceCallStaleCheck isStale;
}

class VoiceCallStartConnectionResult {
  const VoiceCallStartConnectionResult._({
    this.service,
    this.errorMessage,
    this.stale = false,
  });

  const VoiceCallStartConnectionResult.ready(GeminiLiveService service)
      : this._(service: service);

  const VoiceCallStartConnectionResult.failure(String message)
      : this._(errorMessage: message);

  const VoiceCallStartConnectionResult.stale() : this._(stale: true);

  final GeminiLiveService? service;
  final String? errorMessage;
  final bool stale;
}

class VoiceCallStartConnectionStep {
  const VoiceCallStartConnectionStep({
    required VoiceCallConnectionService connectionService,
  }) : _connectionService = connectionService;

  final VoiceCallConnectionService _connectionService;

  Future<VoiceCallStartConnectionResult> connect(
    VoiceCallStartConnectionInput input,
  ) async {
    try {
      final service = await _connectionService.prepare(
        input.startContext.toConnectionInput(input.request),
      );
      if (input.isStale()) {
        await service.dispose();
        return const VoiceCallStartConnectionResult.stale();
      }

      return VoiceCallStartConnectionResult.ready(service);
    } on VoiceCallConnectionException catch (e) {
      if (input.isStale()) return const VoiceCallStartConnectionResult.stale();
      await input.resources?.stopRingtone();
      return VoiceCallStartConnectionResult.failure(e.message);
    } catch (e) {
      debugPrint('[VoiceCallSession] Start failed: $e');
      if (input.isStale()) return const VoiceCallStartConnectionResult.stale();
      await input.resources?.stopRingtone();
      return VoiceCallStartConnectionResult.failure('연결에 실패했습니다: $e');
    }
  }
}
