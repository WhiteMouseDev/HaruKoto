import 'dart:async';

import '../data/gemini_live_service.dart';
import 'voice_call_live_state_coordinator.dart';
import 'voice_call_session_resources.dart';
import 'voice_call_session_state.dart';
import 'voice_call_session_state_reducer.dart';

typedef VoiceCallSessionStateReader = VoiceCallSessionState Function();
typedef VoiceCallSessionStateWriter = void Function(VoiceCallSessionState);
typedef VoiceCallSessionResourcesReader = VoiceCallSessionResources? Function();

class VoiceCallLiveEventHandler {
  const VoiceCallLiveEventHandler({
    required this.getState,
    required this.setState,
    required this.getResources,
    required this.isDisposed,
    this.liveStateCoordinator = const VoiceCallLiveStateCoordinator(),
    this.stateReducer = const VoiceCallSessionStateReducer(),
  });

  final VoiceCallSessionStateReader getState;
  final VoiceCallSessionStateWriter setState;
  final VoiceCallSessionResourcesReader getResources;
  final bool Function() isDisposed;
  final VoiceCallLiveStateCoordinator liveStateCoordinator;
  final VoiceCallSessionStateReducer stateReducer;

  void handleStateChange(GeminiLiveState liveState) {
    final transition = liveStateCoordinator.resolve(liveState);
    setState(stateReducer.applyLiveTransition(getState(), transition));

    if (transition.stopRingtone) {
      unawaited(getResources()?.stopRingtone());
    }
    if (transition.startTimer) {
      _startTimer();
    }
  }

  void appendAiTextDelta(String text) {
    setState(stateReducer.appendAiTextDelta(getState(), text));
  }

  void handleTranscriptEntry(TranscriptEntry entry) {
    setState(stateReducer.applyTranscriptEntry(getState(), entry));
  }

  void setErrorMessage(String message) {
    setState(stateReducer.setErrorMessage(getState(), message));
  }

  void _startTimer() {
    getResources()?.startTimer(() {
      if (isDisposed()) return;
      setState(stateReducer.incrementDuration(getState()));
    });
  }
}
