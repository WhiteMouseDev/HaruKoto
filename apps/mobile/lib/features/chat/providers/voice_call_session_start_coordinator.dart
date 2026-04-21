import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'voice_call_connection_service.dart';
import 'voice_call_live_session_starter.dart';
import 'voice_call_session_resources.dart';
import 'voice_call_session_state.dart';
import 'voice_call_session_state_reducer.dart';
import 'voice_call_start_flow_coordinator.dart';

typedef VoiceCallSessionStaleCheck = bool Function();
typedef VoiceCallSessionStartStateReader = VoiceCallSessionState Function();
typedef VoiceCallSessionStartStateWriter = void Function(VoiceCallSessionState);
typedef VoiceCallStartFlowRunner = Future<VoiceCallStartFlowResult> Function(
  VoiceCallStartFlowInput input,
);
typedef VoiceCallLiveSessionRunner = Future<VoiceCallLiveSessionStartResult>
    Function(
  VoiceCallLiveSessionStartInput input,
);

final voiceCallSessionStartCoordinatorProvider =
    Provider<VoiceCallSessionStartCoordinator>((ref) {
  return VoiceCallSessionStartCoordinator(
    prepareStartFlow: ref.watch(voiceCallStartFlowCoordinatorProvider).prepare,
    startLiveSession: ref.watch(voiceCallLiveSessionStarterProvider).start,
  );
});

class VoiceCallSessionStartInput {
  const VoiceCallSessionStartInput({
    required this.request,
    required this.resources,
    required this.isStale,
    required this.getState,
    required this.setState,
    required this.callbacks,
  });

  final VoiceCallSessionRequest request;
  final VoiceCallSessionResources? resources;
  final VoiceCallSessionStaleCheck isStale;
  final VoiceCallSessionStartStateReader getState;
  final VoiceCallSessionStartStateWriter setState;
  final VoiceCallLiveSessionCallbacks callbacks;
}

class VoiceCallSessionStartCoordinator {
  const VoiceCallSessionStartCoordinator({
    required VoiceCallStartFlowRunner prepareStartFlow,
    required VoiceCallLiveSessionRunner startLiveSession,
    VoiceCallSessionStateReducer stateReducer =
        const VoiceCallSessionStateReducer(),
  })  : _prepareStartFlow = prepareStartFlow,
        _startLiveSession = startLiveSession,
        _stateReducer = stateReducer;

  final VoiceCallStartFlowRunner _prepareStartFlow;
  final VoiceCallLiveSessionRunner _startLiveSession;
  final VoiceCallSessionStateReducer _stateReducer;

  Future<void> start(VoiceCallSessionStartInput input) async {
    final startResult = await _prepareStartFlow(
      VoiceCallStartFlowInput(
        request: input.request,
        resources: input.resources,
        isStale: input.isStale,
        setState: input.setState,
      ),
    );
    if (startResult.stale) return;

    if (startResult.hasError) {
      _fail(input, startResult.errorMessage);
      return;
    }

    final service = startResult.service;
    if (service == null) {
      _fail(input, '연결에 실패했습니다');
      return;
    }

    final startLiveResult = await _startLiveSession(
      VoiceCallLiveSessionStartInput(
        service: service,
        resources: input.resources,
        isActive: () => !input.isStale(),
        callbacks: input.callbacks,
      ),
    );
    if (startLiveResult.stale) return;
    if (startLiveResult.hasError) {
      _fail(input, startLiveResult.errorMessage);
    }
  }

  void _fail(VoiceCallSessionStartInput input, String? errorMessage) {
    input.setState(
      _stateReducer.fail(input.getState(), errorMessage),
    );
  }
}
