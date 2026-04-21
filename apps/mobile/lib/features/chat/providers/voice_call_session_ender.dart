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
  const VoiceCallSessionEnder();

  Future<VoiceCallEndedSession> end(
      VoiceCallSessionResources? resources) async {
    resources?.stopTimer();

    final transcript = resources?.transcript ?? const <TranscriptEntry>[];
    await resources?.endService();

    return VoiceCallEndedSession(transcript: transcript);
  }
}
