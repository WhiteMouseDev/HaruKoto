import '../data/gemini_live_events.dart';
import 'voice_call_session_state.dart';

class VoiceCallLiveStateTransition {
  const VoiceCallLiveStateTransition({
    required this.status,
    this.clearErrorMessage = false,
    this.stopRingtone = false,
    this.startTimer = false,
  });

  final VoiceCallStatus status;
  final bool clearErrorMessage;
  final bool stopRingtone;
  final bool startTimer;
}

class VoiceCallLiveStateCoordinator {
  const VoiceCallLiveStateCoordinator();

  VoiceCallLiveStateTransition resolve(GeminiLiveState liveState) {
    switch (liveState) {
      case GeminiLiveState.connecting:
        return const VoiceCallLiveStateTransition(
          status: VoiceCallStatus.connecting,
        );
      case GeminiLiveState.connected:
        return const VoiceCallLiveStateTransition(
          status: VoiceCallStatus.connected,
          clearErrorMessage: true,
          stopRingtone: true,
          startTimer: true,
        );
      case GeminiLiveState.ending:
        return const VoiceCallLiveStateTransition(
          status: VoiceCallStatus.ending,
          stopRingtone: true,
        );
      case GeminiLiveState.ended:
        return const VoiceCallLiveStateTransition(
          status: VoiceCallStatus.ended,
        );
      case GeminiLiveState.error:
        return const VoiceCallLiveStateTransition(
          status: VoiceCallStatus.error,
          stopRingtone: true,
        );
    }
  }
}
