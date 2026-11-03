import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gemini_live_service.dart';
import 'voice_call_session_resources.dart';

final voiceCallSessionEnderProvider = Provider<VoiceCallSessionEnder>(
  (ref) => const VoiceCallSessionEnder(),
);

class VoiceCallEndedSession {
  const VoiceCallEndedSession({
    required this.transcript,
  });

  final List<TranscriptEntry> transcript;
}

class VoiceCallSessionEnder {
  const VoiceCallSessionEnder({
    Duration shutdownTimeout = const Duration(seconds: 3),
  }) : _shutdownTimeout = shutdownTimeout;

  final Duration _shutdownTimeout;

  Future<VoiceCallEndedSession> end(
      VoiceCallSessionResources? resources) async {
    resources?.stopTimer();

    final transcript = resources?.transcript ?? const <TranscriptEntry>[];
    final service = resources?.service;
    try {
      // The service blocks PCM sending and closes its socket before awaiting
      // native microphone shutdown. That teardown must not lose the record.
      await resources?.endService().timeout(_shutdownTimeout);
    } catch (error) {
      debugPrint(
          '[VoiceCallSession] Audio shutdown incomplete: ${error.runtimeType}');
      // Capture this service: a later call may reuse the resource container.
      // Disposal remains best effort, not proof that the OS microphone stopped.
      unawaited(service?.dispose().catchError((Object error) {
        debugPrint(
            '[VoiceCallSession] Audio disposal failed: ${error.runtimeType}');
      }));
    }

    return VoiceCallEndedSession(transcript: transcript);
  }
}
