import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/user_preferences_provider.dart';
import '../../my/providers/my_provider.dart';
import '../data/gemini_live_service.dart';
import 'voice_call_connection_service.dart';

export 'voice_call_connection_service.dart';

enum VoiceCallStatus {
  connecting,
  connected,
  ending,
  ended,
  error,
}

class VoiceCallAnalysisRequest {
  const VoiceCallAnalysisRequest({
    required this.transcript,
    required this.durationSeconds,
    this.characterId,
    this.characterName,
    this.scenarioId,
  });

  final List<Map<String, String>> transcript;
  final int durationSeconds;
  final String? characterId;
  final String? characterName;
  final String? scenarioId;
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

abstract class VoiceCallRingtonePlayer {
  Future<void> startLoop();
  Future<void> stop();
  Future<void> dispose();
}

class AudioVoiceCallRingtonePlayer implements VoiceCallRingtonePlayer {
  AudioVoiceCallRingtonePlayer() : _player = AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> startLoop() async {
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(0.5);
    await _player.play(AssetSource('sounds/ringtone.wav'));
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}

typedef VoiceCallRingtonePlayerFactory = VoiceCallRingtonePlayer Function();

final voiceCallRingtonePlayerFactoryProvider =
    Provider<VoiceCallRingtonePlayerFactory>(
  (ref) => AudioVoiceCallRingtonePlayer.new,
);

class VoiceCallSessionController extends Notifier<VoiceCallSessionState> {
  GeminiLiveService? _service;
  Timer? _timer;
  VoiceCallRingtonePlayer? _ringtone;
  VoiceCallSessionRequest? _request;
  bool _disposed = false;
  bool _isEnding = false;
  int _generation = 0;

  @override
  VoiceCallSessionState build() {
    _ringtone ??= ref.read(voiceCallRingtonePlayerFactoryProvider)();
    ref.onDispose(() {
      _disposed = true;
      _generation++;
      unawaited(_disposeResources());
    });
    return const VoiceCallSessionState();
  }

  Future<void> initialize(VoiceCallSessionRequest request) async {
    _request = request;
    final generation = ++_generation;
    _isEnding = false;

    await _cancelActiveSession();
    if (_isStale(generation)) return;

    final preferences = ref.read(userPreferencesProvider);
    final profileAsync = ref.read(profileDetailProvider);
    final nickname =
        profileAsync.hasValue ? profileAsync.value!.profile.nickname : '학습자';

    state = VoiceCallSessionState(
      status: VoiceCallStatus.connecting,
      showSubtitle: preferences.callSettings.subtitleEnabled,
    );

    await _playRingtone();
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

      _service = service;
      _bindService(service, generation);
      await service.start();
    } on VoiceCallConnectionException catch (e) {
      if (_isStale(generation)) return;
      await _stopRingtone();
      state = state.copyWith(
        status: VoiceCallStatus.error,
        errorMessage: e.message,
      );
    } catch (e) {
      debugPrint('[VoiceCallSession] Start failed: $e');
      if (_isStale(generation)) return;
      await _stopRingtone();
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
    _service?.isMuted = nextMuted;
  }

  void toggleSubtitle() {
    state = state.copyWith(showSubtitle: !state.showSubtitle);
  }

  Future<VoiceCallEndResult> endCall() async {
    if (_isEnding) {
      return const VoiceCallEndResult(ignored: true);
    }

    _isEnding = true;
    _timer?.cancel();
    _timer = null;

    final transcript = _service?.transcript ?? const <TranscriptEntry>[];
    final duration = state.callDurationSeconds;
    final request = _request;

    await _service?.end();

    final autoAnalysis =
        ref.read(userPreferencesProvider).callSettings.autoAnalysis;
    if (request == null ||
        !autoAnalysis ||
        duration < 15 ||
        transcript.isEmpty) {
      return const VoiceCallEndResult();
    }

    return VoiceCallEndResult(
      analysisRequest: VoiceCallAnalysisRequest(
        transcript: transcript.map((entry) => entry.toJson()).toList(),
        durationSeconds: duration,
        characterId: request.characterId,
        characterName: request.characterName,
        scenarioId: request.scenarioId,
      ),
    );
  }

  void _bindService(GeminiLiveService service, int generation) {
    service.onStateChange = (liveState) {
      if (_isStale(generation)) return;
      switch (liveState) {
        case GeminiLiveState.connecting:
          state = state.copyWith(status: VoiceCallStatus.connecting);
          return;
        case GeminiLiveState.connected:
          state = state.copyWith(
            status: VoiceCallStatus.connected,
            errorMessage: null,
          );
          unawaited(_stopRingtone());
          _startTimer();
          return;
        case GeminiLiveState.ending:
          state = state.copyWith(status: VoiceCallStatus.ending);
          unawaited(_stopRingtone());
          return;
        case GeminiLiveState.ended:
          state = state.copyWith(status: VoiceCallStatus.ended);
          return;
        case GeminiLiveState.error:
          state = state.copyWith(status: VoiceCallStatus.error);
          unawaited(_stopRingtone());
          return;
      }
    };

    service.onAiTextDelta = (text) {
      if (_isStale(generation)) return;
      state = state.copyWith(currentAiText: state.currentAiText + text);
    };

    service.onTranscriptEntry = (entry) {
      if (_isStale(generation)) return;
      if (entry.role == 'assistant') {
        state = state.copyWith(currentAiText: '');
      }
    };

    service.onError = (message) {
      if (_isStale(generation)) return;
      state = state.copyWith(errorMessage: message);
    };
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      state = state.copyWith(
        callDurationSeconds: state.callDurationSeconds + 1,
      );
    });
  }

  Future<void> _playRingtone() async {
    try {
      await _ringtone?.startLoop();
    } catch (e) {
      debugPrint('[VoiceCallSession] Ringtone play failed: $e');
    }
  }

  Future<void> _stopRingtone() async {
    try {
      await _ringtone?.stop();
    } catch (_) {}
  }

  Future<void> _cancelActiveSession() async {
    _timer?.cancel();
    _timer = null;
    await _stopRingtone();
    final service = _service;
    _service = null;
    if (service == null) return;
    try {
      await service.dispose();
    } catch (e) {
      debugPrint('[VoiceCallSession] Service dispose failed: $e');
    }
  }

  Future<void> _disposeResources() async {
    await _cancelActiveSession();
    final ringtone = _ringtone;
    _ringtone = null;
    try {
      await ringtone?.dispose();
    } catch (_) {}
  }

  bool _isStale(int generation) => _disposed || generation != _generation;
}

final voiceCallSessionProvider =
    NotifierProvider<VoiceCallSessionController, VoiceCallSessionState>(
  VoiceCallSessionController.new,
);
