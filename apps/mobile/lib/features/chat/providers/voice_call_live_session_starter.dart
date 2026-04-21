import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gemini_live_service.dart';
import 'voice_call_live_event_binder.dart';
import 'voice_call_session_resources.dart';

typedef VoiceCallLiveActiveCheck = bool Function();

final voiceCallLiveSessionStarterProvider =
    Provider<VoiceCallLiveSessionStarter>((ref) {
  return const VoiceCallLiveSessionStarter();
});

class VoiceCallLiveSessionCallbacks {
  const VoiceCallLiveSessionCallbacks({
    required this.onStateChange,
    required this.onAiTextDelta,
    required this.onTranscriptEntry,
    required this.onError,
  });

  final void Function(GeminiLiveState state) onStateChange;
  final void Function(String text) onAiTextDelta;
  final void Function(TranscriptEntry entry) onTranscriptEntry;
  final void Function(String message) onError;
}

class VoiceCallLiveSessionStartInput {
  const VoiceCallLiveSessionStartInput({
    required this.service,
    required this.resources,
    required this.isActive,
    required this.callbacks,
  });

  final GeminiLiveService service;
  final VoiceCallSessionResources? resources;
  final VoiceCallLiveActiveCheck isActive;
  final VoiceCallLiveSessionCallbacks callbacks;
}

class VoiceCallLiveSessionStartResult {
  const VoiceCallLiveSessionStartResult._({
    this.errorMessage,
    this.stale = false,
  });

  const VoiceCallLiveSessionStartResult.success() : this._();

  const VoiceCallLiveSessionStartResult.failure(String message)
      : this._(errorMessage: message);

  const VoiceCallLiveSessionStartResult.stale() : this._(stale: true);

  final String? errorMessage;
  final bool stale;

  bool get hasError => errorMessage != null;
}

class VoiceCallLiveSessionStarter {
  const VoiceCallLiveSessionStarter();

  Future<VoiceCallLiveSessionStartResult> start(
    VoiceCallLiveSessionStartInput input,
  ) async {
    try {
      input.resources?.attachService(input.service);
      VoiceCallLiveEventBinder(
        service: input.service,
        isActive: input.isActive,
        onStateChange: input.callbacks.onStateChange,
        onAiTextDelta: input.callbacks.onAiTextDelta,
        onTranscriptEntry: input.callbacks.onTranscriptEntry,
        onError: input.callbacks.onError,
      ).bind();
      await input.service.start();
      return const VoiceCallLiveSessionStartResult.success();
    } catch (e) {
      debugPrint('[VoiceCallSession] Start failed: $e');
      if (!input.isActive()) {
        return const VoiceCallLiveSessionStartResult.stale();
      }
      await input.resources?.stopRingtone();
      return VoiceCallLiveSessionStartResult.failure('연결에 실패했습니다: $e');
    }
  }
}
