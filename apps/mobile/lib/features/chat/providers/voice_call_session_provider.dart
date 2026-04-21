import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gemini_live_service.dart';
import 'voice_call_analysis_request_factory.dart';
import 'voice_call_connection_service.dart';
import 'voice_call_end_flow_coordinator.dart';
import 'voice_call_live_event_binder.dart';
import 'voice_call_live_state_coordinator.dart';
import 'voice_call_session_resources.dart';
import 'voice_call_session_state.dart';
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
      state = state.copyWith(
        status: VoiceCallStatus.error,
        errorMessage: startResult.errorMessage,
      );
      return;
    }

    final service = startResult.service;
    if (service == null) {
      state = state.copyWith(
        status: VoiceCallStatus.error,
        errorMessage: '연결에 실패했습니다',
      );
      return;
    }

    try {
      _resources?.attachService(service);
      _bindService(service, generation);
      await service.start();
    } catch (e) {
      debugPrint('[VoiceCallSession] Start failed: $e');
      if (_isStale(generation)) return;
      await _resources?.stopRingtone();
      state = state.copyWith(
        status: VoiceCallStatus.error,
        errorMessage: '연결에 실패했습니다: $e',
      );
    }
  }

  Future<void> retry() async {
    final request = _request;
    if (request == null) return;
    await initialize(request);
  }

  void toggleMute() {
    final nextMuted = !state.isMuted;
    state = state.copyWith(isMuted: nextMuted);
    _resources?.setMuted(nextMuted);
  }

  void toggleSubtitle() {
    state = state.copyWith(showSubtitle: !state.showSubtitle);
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

  void _bindService(GeminiLiveService service, int generation) {
    VoiceCallLiveEventBinder(
      service: service,
      isActive: () => !_isStale(generation),
      onStateChange: _handleLiveStateChange,
      onAiTextDelta: _appendAiTextDelta,
      onTranscriptEntry: _handleTranscriptEntry,
      onError: _setErrorMessage,
    ).bind();
  }

  void _handleLiveStateChange(GeminiLiveState liveState) {
    final transition = _liveStateCoordinator.resolve(liveState);
    state = transition.clearErrorMessage
        ? state.copyWith(
            status: transition.status,
            errorMessage: null,
          )
        : state.copyWith(status: transition.status);

    if (transition.stopRingtone) {
      unawaited(_resources?.stopRingtone());
    }
    if (transition.startTimer) {
      _startTimer();
    }
  }

  void _appendAiTextDelta(String text) {
    state = state.copyWith(currentAiText: state.currentAiText + text);
  }

  void _handleTranscriptEntry(TranscriptEntry entry) {
    if (entry.role == 'assistant') {
      state = state.copyWith(currentAiText: '');
    }
  }

  void _setErrorMessage(String message) {
    state = state.copyWith(errorMessage: message);
  }

  void _startTimer() {
    _resources?.startTimer(() {
      if (_disposed) return;
      state = state.copyWith(
        callDurationSeconds: state.callDurationSeconds + 1,
      );
    });
  }

  bool _isStale(int generation) => _disposed || generation != _generation;
}

final voiceCallSessionProvider =
    NotifierProvider<VoiceCallSessionController, VoiceCallSessionState>(
  VoiceCallSessionController.new,
);
