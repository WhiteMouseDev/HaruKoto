import 'voice_call_session_resources.dart';
import 'voice_call_session_state.dart';
import 'voice_call_microphone_permission.dart';
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
  const VoiceCallStartPreparationResult.ready(this.context)
      : errorMessage = null,
        canRetry = true,
        stale = false;
  const VoiceCallStartPreparationResult.failure(
    String message, {
    this.canRetry = true,
  })  : context = null,
        errorMessage = message,
        stale = false;
  const VoiceCallStartPreparationResult.stale()
      : context = null,
        errorMessage = null,
        canRetry = true,
        stale = true;

  final VoiceCallStartContext? context;
  final String? errorMessage;
  final bool canRetry;
  final bool stale;

  bool get hasError => errorMessage != null;
}

class VoiceCallStartPreparationStep {
  VoiceCallStartPreparationStep({
    required VoiceCallStartContextReader startContextReader,
    VoiceCallMicrophonePermissionRequester requestMicrophonePermission =
        allowVoiceCallMicrophonePermission,
  })  : _startContextReader = startContextReader,
        _requestMicrophonePermission = requestMicrophonePermission;

  final VoiceCallStartContextReader _startContextReader;
  final VoiceCallMicrophonePermissionRequester _requestMicrophonePermission;

  Future<VoiceCallStartPreparationResult> prepare(
    VoiceCallStartPreparationInput input,
  ) async {
    await input.resources?.cancelActiveSession();
    if (input.isStale()) {
      return const VoiceCallStartPreparationResult.stale();
    }

    final microphonePermission = await _requestMicrophonePermission();
    if (input.isStale()) {
      return const VoiceCallStartPreparationResult.stale();
    }
    switch (microphonePermission) {
      case VoiceCallMicrophonePermissionResult.granted:
        break;
      case VoiceCallMicrophonePermissionResult.denied:
        return const VoiceCallStartPreparationResult.failure(
          '마이크 권한이 필요합니다',
        );
      case VoiceCallMicrophonePermissionResult.checkFailed:
        return const VoiceCallStartPreparationResult.failure(
          '마이크 권한을 확인할 수 없습니다. 설정을 확인해주세요.',
        );
    }

    final startContext = await _startContextReader.read();
    if (input.isStale()) {
      return const VoiceCallStartPreparationResult.stale();
    }
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
