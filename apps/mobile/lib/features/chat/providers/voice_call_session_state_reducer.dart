import '../data/gemini_live_transcript.dart';
import 'voice_call_live_state_coordinator.dart';
import 'voice_call_session_state.dart';

class VoiceCallSessionStateReducer {
  const VoiceCallSessionStateReducer();

  VoiceCallSessionState fail(
    VoiceCallSessionState state,
    String? errorMessage,
  ) {
    return state.copyWith(
      status: VoiceCallStatus.error,
      errorMessage: errorMessage,
    );
  }

  VoiceCallSessionState toggleMute(VoiceCallSessionState state) {
    return state.copyWith(isMuted: !state.isMuted);
  }

  VoiceCallSessionState toggleSubtitle(VoiceCallSessionState state) {
    return state.copyWith(showSubtitle: !state.showSubtitle);
  }

  VoiceCallSessionState applyLiveTransition(
    VoiceCallSessionState state,
    VoiceCallLiveStateTransition transition,
  ) {
    if (transition.clearErrorMessage) {
      return state.copyWith(
        status: transition.status,
        errorMessage: null,
      );
    }
    return state.copyWith(status: transition.status);
  }

  VoiceCallSessionState appendAiTextDelta(
    VoiceCallSessionState state,
    String text,
  ) {
    return state.copyWith(currentAiText: state.currentAiText + text);
  }

  VoiceCallSessionState applyTranscriptEntry(
    VoiceCallSessionState state,
    TranscriptEntry entry,
  ) {
    if (entry.role != 'assistant') return state;
    return state.copyWith(currentAiText: '');
  }

  VoiceCallSessionState setErrorMessage(
    VoiceCallSessionState state,
    String message,
  ) {
    return state.copyWith(errorMessage: message);
  }

  VoiceCallSessionState incrementDuration(VoiceCallSessionState state) {
    return state.copyWith(
      callDurationSeconds: state.callDurationSeconds + 1,
    );
  }
}
