import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/user_preferences_provider.dart';
import '../../my/providers/my_provider.dart';
import '../data/gemini_live_service.dart';
import 'voice_call_live_event_binder.dart';
import 'voice_call_analysis_request_factory.dart';
import 'voice_call_connection_service.dart';
import 'voice_call_session_resources.dart';

export 'voice_call_analysis_request_factory.dart';
export 'voice_call_connection_service.dart';
export 'voice_call_session_resources.dart';

enum VoiceCallStatus {
  connecting,
  connected,
  ending,
  ended,
  error,
}

class VoiceCallEndResult {
  const VoiceCallEndResult({
    this.analysisRequest,
    this.ignored = false,
  });

  final VoiceCallAnalysisRequest? analysisRequest;
  final bool ignored;
}

class VoiceCallSessionState {
  const VoiceCallSessionState({
    this.status = VoiceCallStatus.connecting,
    this.callDurationSeconds = 0,
    this.isMuted = false,
    this.showSubtitle = true,
    this.currentAiText = '',
    this.errorMessage,
  });

  static const _unset = Object();

  final VoiceCallStatus status;
  final int callDurationSeconds;
  final bool isMuted;
  final bool showSubtitle;
  final String currentAiText;
  final String? errorMessage;

  String get formattedDuration {
    final mins = (callDurationSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (callDurationSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  String get statusLabel {
    switch (status) {
      case VoiceCallStatus.connecting:
        return '연결 중...';
      case VoiceCallStatus.ending:
        return '통화 종료 중...';
      case VoiceCallStatus.error:
        return '연결 실패';
      case VoiceCallStatus.connected:
        return formattedDuration;
      case VoiceCallStatus.ended:
        return '통화 종료';
    }
  }

  bool get isConnected => status == VoiceCallStatus.connected;

  bool get canRetry => status == VoiceCallStatus.error;

  VoiceCallSessionState copyWith({
    VoiceCallStatus? status,
    int? callDurationSeconds,
    bool? isMuted,
    bool? showSubtitle,
    String? currentAiText,
    Object? errorMessage = _unset,
  }) {
    return VoiceCallSessionState(
      status: status ?? this.status,
      callDurationSeconds: callDurationSeconds ?? this.callDurationSeconds,
      isMuted: isMuted ?? this.isMuted,
      showSubtitle: showSubtitle ?? this.showSubtitle,
      currentAiText: currentAiText ?? this.currentAiText,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

class VoiceCallSessionController extends Notifier<VoiceCallSessionState> {
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

    await _resources?.cancelActiveSession();
    if (_isStale(generation)) return;

    final preferences = ref.read(userPreferencesProvider);
    final profileAsync = ref.read(profileDetailProvider);
    final nickname =
        profileAsync.hasValue ? profileAsync.value!.profile.nickname : '학습자';

    state = VoiceCallSessionState(
      status: VoiceCallStatus.connecting,
      showSubtitle: preferences.callSettings.subtitleEnabled,
    );

    await _resources?.playRingtone();
    if (_isStale(generation)) return;

    try {
      final service =
          await ref.read(voiceCallConnectionServiceProvider).prepare(
                VoiceCallConnectionInput(
                  request: request,
                  callSettings: preferences.callSettings,
                  userNickname: nickname,
                  jlptLevel: preferences.jlptLevel,
                ),
              );
      if (_isStale(generation)) {
        await service.dispose();
        return;
      }

      _resources?.attachService(service);
      _bindService(service, generation);
      await service.start();
    } on VoiceCallConnectionException catch (e) {
      if (_isStale(generation)) return;
      await _resources?.stopRingtone();
      state = state.copyWith(
        status: VoiceCallStatus.error,
        errorMessage: e.message,
      );
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
    _resources?.stopTimer();

    final transcript = _resources?.transcript ?? const <TranscriptEntry>[];
    final duration = state.callDurationSeconds;
    final request = _request;

    await _resources?.endService();

    final analysisRequest =
        ref.read(voiceCallAnalysisRequestFactoryProvider).build(
              VoiceCallAnalysisRequestInput(
                request: request,
                transcript: transcript,
                durationSeconds: duration,
                autoAnalysis:
                    ref.read(userPreferencesProvider).callSettings.autoAnalysis,
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
    switch (liveState) {
      case GeminiLiveState.connecting:
        state = state.copyWith(status: VoiceCallStatus.connecting);
        return;
      case GeminiLiveState.connected:
        state = state.copyWith(
          status: VoiceCallStatus.connected,
          errorMessage: null,
        );
        unawaited(_resources?.stopRingtone());
        _startTimer();
        return;
      case GeminiLiveState.ending:
        state = state.copyWith(status: VoiceCallStatus.ending);
        unawaited(_resources?.stopRingtone());
        return;
      case GeminiLiveState.ended:
        state = state.copyWith(status: VoiceCallStatus.ended);
        return;
      case GeminiLiveState.error:
        state = state.copyWith(status: VoiceCallStatus.error);
        unawaited(_resources?.stopRingtone());
        return;
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
