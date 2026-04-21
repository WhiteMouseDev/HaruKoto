import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'voice_call_connection_service.dart';
import 'voice_call_end_call_handler.dart';
import 'voice_call_live_event_handler.dart';
import 'voice_call_live_session_starter.dart';
import 'voice_call_session_resources.dart';
import 'voice_call_session_state.dart';
import 'voice_call_session_state_reducer.dart';
import 'voice_call_start_flow_coordinator.dart';

export 'voice_call_analysis_request_factory.dart';
export 'voice_call_connection_service.dart';
export 'voice_call_end_call_handler.dart';
export 'voice_call_session_resources.dart';
export 'voice_call_session_state.dart';

class VoiceCallSessionController extends Notifier<VoiceCallSessionState> {
  static const _stateReducer = VoiceCallSessionStateReducer();

  VoiceCallSessionResources? _resources;
  VoiceCallEndCallHandler? _endCallHandler;
  VoiceCallLiveEventHandler? _liveEventHandler;
  VoiceCallSessionRequest? _request;
  bool _disposed = false;
  int _generation = 0;

  @override
  VoiceCallSessionState build() {
    _resources ??= VoiceCallSessionResources(
      ref.read(voiceCallRingtonePlayerFactoryProvider)(),
    );
    _endCallHandler ??= ref.read(voiceCallEndCallHandlerProvider);
    _liveEventHandler ??= VoiceCallLiveEventHandler(
      getState: () => state,
      setState: (nextState) => state = nextState,
      getResources: () => _resources,
      isDisposed: () => _disposed,
    );
    ref.onDispose(() {
      _disposed = true;
      _generation++;
      unawaited(_resources?.dispose());
    });
    return const VoiceCallSessionState();
  }

  Future<void> initialize(VoiceCallSessionRequest request) async {
    _request = request;
    final generation = ++_generation;
    _endCallHandler?.reset();

    final startResult =
        await ref.read(voiceCallStartFlowCoordinatorProvider).prepare(
              VoiceCallStartFlowInput(
                request: request,
                resources: _resources,
                isStale: () => _isStale(generation),
                setState: (nextState) => state = nextState,
              ),
            );
    if (startResult.stale) return;

    if (startResult.hasError) {
      state = _stateReducer.fail(state, startResult.errorMessage);
      return;
    }

    final service = startResult.service;
    if (service == null) {
      state = _stateReducer.fail(state, '연결에 실패했습니다');
      return;
    }

    final startLiveResult =
        await ref.read(voiceCallLiveSessionStarterProvider).start(
              VoiceCallLiveSessionStartInput(
                service: service,
                resources: _resources,
                isActive: () => !_isStale(generation),
                callbacks: VoiceCallLiveSessionCallbacks(
                  onStateChange: _liveEventHandler!.handleStateChange,
                  onAiTextDelta: _liveEventHandler!.appendAiTextDelta,
                  onTranscriptEntry: _liveEventHandler!.handleTranscriptEntry,
                  onError: _liveEventHandler!.setErrorMessage,
                ),
              ),
            );
    if (startLiveResult.stale) return;
    if (startLiveResult.hasError) {
      state = _stateReducer.fail(state, startLiveResult.errorMessage);
    }
  }

  Future<void> retry() async {
    final request = _request;
    if (request == null) return;
    await initialize(request);
  }

  void toggleMute() {
    state = _stateReducer.toggleMute(state);
    _resources?.setMuted(state.isMuted);
  }

  void toggleSubtitle() {
    state = _stateReducer.toggleSubtitle(state);
  }

  Future<VoiceCallEndResult> endCall() async {
    return _endCallHandler!.end(
      VoiceCallEndCallInput(
        resources: _resources,
        request: _request,
        durationSeconds: state.callDurationSeconds,
      ),
    );
  }

  bool _isStale(int generation) => _disposed || generation != _generation;
}

final voiceCallSessionProvider =
    NotifierProvider<VoiceCallSessionController, VoiceCallSessionState>(
  VoiceCallSessionController.new,
);
