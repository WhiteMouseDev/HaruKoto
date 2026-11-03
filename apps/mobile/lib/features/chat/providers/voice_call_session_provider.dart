import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'voice_call_connection_service.dart';
import '../data/voice_session_id.dart';
import '../data/gemini_live_service.dart';
import 'voice_call_end_call_handler.dart';
import 'voice_call_live_event_handler.dart';
import 'voice_call_live_session_starter.dart';
import 'voice_call_session_lifecycle.dart';
import 'voice_call_session_resources.dart';
import 'voice_call_session_state.dart';
import 'voice_call_session_state_reducer.dart';
import 'voice_call_session_start_coordinator.dart';

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
  Future<void>? _pendingStart;
  bool _ending = false;
  bool _appActive = true;
  int _microphoneAttempt = 0;
  late VoiceCallSessionLifecycle _lifecycle;

  @override
  VoiceCallSessionState build() {
    // Riverpod can rebuild the same Notifier after invalidation. Each build
    // owns a separate lifecycle so pending work cannot revive a disposed call.
    final lifecycle = VoiceCallSessionLifecycle();
    final resources = VoiceCallSessionResources(
      ref.read(voiceCallRingtonePlayerFactoryProvider)(),
    );
    _lifecycle = lifecycle;
    _resources = resources;
    _pendingStart = null;
    _ending = false;
    _appActive = true;
    _microphoneAttempt++;
    _endCallHandler = ref.read(voiceCallEndCallHandlerProvider);
    _liveEventHandler = VoiceCallLiveEventHandler(
      getState: () => state,
      setState: (nextState) {
        if (!lifecycle.isDisposed) state = nextState;
      },
      getResources: () => resources,
      isDisposed: () => lifecycle.isDisposed,
    );
    ref.onDispose(() {
      resources.markCancelled(lifecycle.request?.conversationId);
      lifecycle.markDisposed();
      unawaited(resources.dispose());
    });
    return const VoiceCallSessionState();
  }

  Future<void> initialize(VoiceCallSessionRequest request) async {
    request = request.conversationId == null
        ? request.withConversationId(createVoiceSessionId())
        : request;
    final lifecycle = _lifecycle;
    final resources = _resources;
    final liveEventHandler = _liveEventHandler!;
    final generation = lifecycle.begin(request);
    _endCallHandler?.reset();
    _ending = false;

    final pending = ref.read(voiceCallSessionStartCoordinatorProvider).start(
          VoiceCallSessionStartInput(
            request: request,
            resources: resources,
            isStale: () => lifecycle.isStale(generation),
            getState: () => state,
            setState: (nextState) {
              if (lifecycle.isStale(generation)) return;
              nextState = nextState.copyWith(
                isAppActive: _appActive,
              );
              state = request.scenarioId != null &&
                      nextState.status == VoiceCallStatus.connecting
                  ? nextState.copyWith(showSubtitle: true)
                  : nextState;
            },
            callbacks: VoiceCallLiveSessionCallbacks(
              onStateChange: (liveState) {
                liveEventHandler.handleStateChange(liveState);
                if (liveState != GeminiLiveState.connected &&
                    state.resumingMicrophone) {
                  _suspendMicrophone(resources);
                }
                if (liveState == GeminiLiveState.connected && !_appActive) {
                  _suspendMicrophone(resources);
                }
              },
              onAiTextDelta: liveEventHandler.appendAiTextDelta,
              onTranscriptEntry: liveEventHandler.handleTranscriptEntry,
              onError: liveEventHandler.setErrorMessage,
              onMicrophoneInterrupted: () {
                if (lifecycle.isStale(generation)) return;
                _microphoneAttempt++;
                state = state.copyWith(
                  microphoneInterrupted: true,
                  resumingMicrophone: false,
                );
              },
            ),
          ),
        );
    _pendingStart = pending;
    await pending;
    if (identical(_pendingStart, pending)) _pendingStart = null;
  }

  Future<void> retry() async {
    final request = _lifecycle.request;
    if (request == null || _ending || state.hasConnected) return;
    await initialize(request);
  }

  void toggleMute() => setMuted(!state.isMuted);

  void setAppActive(bool active) {
    if (_appActive == active) return;
    _appActive = active;
    state = state.copyWith(isAppActive: active);
    if (!active && !_ending && (state.isConnected || state.hasConnected)) {
      _suspendMicrophone(_resources);
    }
  }

  void _suspendMicrophone(VoiceCallSessionResources? resources) {
    _microphoneAttempt++;
    state = state.copyWith(
      microphoneInterrupted: true,
      resumingMicrophone: false,
    );
    unawaited(
        resources?.service?.suspendMicrophone().catchError((Object _) {}));
  }

  Future<bool> resumeMicrophone() async {
    if (_ending ||
        !_appActive ||
        !state.isConnected ||
        !state.microphoneInterrupted ||
        state.resumingMicrophone) {
      return false;
    }
    final service = _resources?.service;
    if (service == null) return false;
    final lifecycle = _lifecycle;
    final attempt = ++_microphoneAttempt;
    state = state.copyWith(resumingMicrophone: true);
    bool resumed;
    try {
      resumed = await service.resumeMicrophone();
    } catch (_) {
      resumed = false;
    }
    if (lifecycle.isDisposed ||
        attempt != _microphoneAttempt ||
        _ending ||
        !_appActive ||
        !state.isConnected) {
      return false;
    }
    state = state.copyWith(
      microphoneInterrupted: !resumed,
      resumingMicrophone: false,
    );
    return resumed;
  }

  void setMuted(bool muted) {
    state = state.copyWith(isMuted: muted);
    _resources?.setMuted(muted);
  }

  Future<bool> requestHelp(GeminiLiveHelpAction action,
      {String? targetText}) async {
    if (!state.isConnected) return false;
    return await _resources?.service
            ?.requestHelp(action, targetText: targetText) ??
        false;
  }

  void toggleSubtitle() {
    state = _stateReducer.toggleSubtitle(state);
  }

  Future<VoiceCallEndResult> endCall() async {
    if (_ending) return const VoiceCallEndResult(ignored: true);
    _ending = true;
    _microphoneAttempt++;
    final lifecycle = _lifecycle;
    final resources = _resources;
    final endCallHandler = _endCallHandler!;
    final durationSeconds = state.callDurationSeconds;
    final request = lifecycle.request;
    final wasConnected = state.hasConnected ||
        state.isConnected ||
        state.callDurationSeconds > 0;
    lifecycle.cancelPending();
    resources?.markCancelled(request?.conversationId);
    resources?.setMuted(true);
    resources?.stopTimer();
    unawaited(resources?.stopRingtone());
    if (_pendingStart != null) {
      unawaited(resources?.endService().catchError((Object _) {}));
    }
    state = state.copyWith(status: VoiceCallStatus.ending);
    final pendingStart = _pendingStart;
    if (pendingStart != null) {
      await pendingStart.timeout(const Duration(seconds: 2), onTimeout: () {});
    }
    if (lifecycle.isDisposed) return const VoiceCallEndResult(ignored: true);
    return endCallHandler.end(
      VoiceCallEndCallInput(
        resources: resources,
        request: request,
        durationSeconds: durationSeconds,
        wasConnected: wasConnected,
      ),
    );
  }
}

final voiceCallSessionProvider =
    NotifierProvider<VoiceCallSessionController, VoiceCallSessionState>(
  VoiceCallSessionController.new,
);
