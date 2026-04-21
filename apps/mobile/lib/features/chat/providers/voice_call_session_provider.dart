import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gemini_live_events.dart';
import '../data/gemini_live_transcript.dart';
import 'voice_call_analysis_request_factory.dart';
import 'voice_call_connection_service.dart';
import 'voice_call_end_flow_coordinator.dart';
import 'voice_call_live_session_starter.dart';
import 'voice_call_live_state_coordinator.dart';
import 'voice_call_session_resources.dart';
import 'voice_call_session_state.dart';
import 'voice_call_session_state_reducer.dart';
import 'voice_call_start_flow_coordinator.dart';

export 'voice_call_analysis_request_factory.dart';
export 'voice_call_connection_service.dart';
export 'voice_call_session_resources.dart';
export 'voice_call_session_state.dart';

class VoiceCallEndResult {
  const VoiceCallEndResult({
    this.analysisRequest,
    this.ignored = false,
  });

  final VoiceCallAnalysisRequest? analysisRequest;
  final bool ignored;
}

class VoiceCallSessionController extends Notifier<VoiceCallSessionState> {
  static const _liveStateCoordinator = VoiceCallLiveStateCoordinator();
  static const _stateReducer = VoiceCallSessionStateReducer();

  VoiceCallSessionResources? _resources;
  VoiceCallSessionRequest? _request;
  bool _disposed = false;
  bool _isEnding = false;
  int _generation = 0;

  @override
  VoiceCallSessionState build() {
    _resources ??= VoiceCallSessionResources(
      ref.read(voiceCallRingtonePlayerFactoryProvider)(),
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
    _isEnding = false;

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
                  onStateChange: _handleLiveStateChange,
                  onAiTextDelta: _appendAiTextDelta,
                  onTranscriptEntry: _handleTranscriptEntry,
                  onError: _setErrorMessage,
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
    if (_isEnding) {
      return const VoiceCallEndResult(ignored: true);
    }

    _isEnding = true;
    final analysisRequest =
        await ref.read(voiceCallEndFlowCoordinatorProvider).end(
              VoiceCallEndFlowInput(
                resources: _resources,
                request: _request,
                durationSeconds: state.callDurationSeconds,
              ),
            );

    return VoiceCallEndResult(analysisRequest: analysisRequest);
  }

  void _handleLiveStateChange(GeminiLiveState liveState) {
    final transition = _liveStateCoordinator.resolve(liveState);
    state = _stateReducer.applyLiveTransition(state, transition);

    if (transition.stopRingtone) {
      unawaited(_resources?.stopRingtone());
    }
    if (transition.startTimer) {
      _startTimer();
    }
  }

  void _appendAiTextDelta(String text) {
    state = _stateReducer.appendAiTextDelta(state, text);
  }

  void _handleTranscriptEntry(TranscriptEntry entry) {
    state = _stateReducer.applyTranscriptEntry(state, entry);
  }

  void _setErrorMessage(String message) {
    state = _stateReducer.setErrorMessage(state, message);
  }

  void _startTimer() {
    _resources?.startTimer(() {
      if (_disposed) return;
      state = _stateReducer.incrementDuration(state);
    });
  }

  bool _isStale(int generation) => _disposed || generation != _generation;
}

final voiceCallSessionProvider =
    NotifierProvider<VoiceCallSessionController, VoiceCallSessionState>(
  VoiceCallSessionController.new,
);
