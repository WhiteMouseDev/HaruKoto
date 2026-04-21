import 'voice_call_session_resources.dart';
import 'voice_call_session_state.dart';
import 'voice_call_start_context_reader.dart';

typedef VoiceCallStaleCheck = bool Function();
typedef VoiceCallStateSetter = void Function(VoiceCallSessionState state);

class VoiceCallStartPreparationInput {
  const VoiceCallStartPreparationInput({
    required this.resources,
    required this.isStale,
    required this.setState,
  });

  final VoiceCallSessionResources? resources;
  final VoiceCallStaleCheck isStale;
  final VoiceCallStateSetter setState;
}

class VoiceCallStartPreparationResult {
  const VoiceCallStartPreparationResult.ready(this.context) : stale = false;
  const VoiceCallStartPreparationResult.stale()
      : context = null,
        stale = true;

  final VoiceCallStartContext? context;
  final bool stale;
}

class VoiceCallStartPreparationStep {
  const VoiceCallStartPreparationStep({
    required VoiceCallStartContextReader startContextReader,
  }) : _startContextReader = startContextReader;

  final VoiceCallStartContextReader _startContextReader;

  Future<VoiceCallStartPreparationResult> prepare(
    VoiceCallStartPreparationInput input,
  ) async {
    await input.resources?.cancelActiveSession();
    if (input.isStale()) {
      return const VoiceCallStartPreparationResult.stale();
    }

    final startContext = _startContextReader.read();
    input.setState(
      VoiceCallSessionState(
        status: VoiceCallStatus.connecting,
        showSubtitle: startContext.callSettings.subtitleEnabled,
      ),
    );

    await input.resources?.playRingtone();
    if (input.isStale()) {
      return const VoiceCallStartPreparationResult.stale();
    }

    return VoiceCallStartPreparationResult.ready(startContext);
  }
}
