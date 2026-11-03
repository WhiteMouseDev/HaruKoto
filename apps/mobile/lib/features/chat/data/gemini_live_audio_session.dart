import 'dart:async';

import 'package:flutter/foundation.dart';

import 'gemini_live_audio_adapter.dart';
import 'gemini_live_outbound_sender.dart';

class GeminiLiveAudioSession {
  GeminiLiveAudioSession({
    required GeminiLiveAudioAdapter audioAdapter,
    required GeminiLiveOutboundSender outboundSender,
    required bool Function() isActive,
    required bool Function() isTransportConnected,
    required bool Function() isMuted,
    required void Function(String message) onError,
    required void Function() onUnavailable,
    void Function()? onMicrophoneInterrupted,
  })  : _audioAdapter = audioAdapter,
        _outboundSender = outboundSender,
        _isActive = isActive,
        _isTransportConnected = isTransportConnected,
        _isMuted = isMuted,
        _onError = onError,
        _onUnavailable = onUnavailable,
        _onMicrophoneInterrupted = onMicrophoneInterrupted {
    final source = _audioAdapter;
    if (source is GeminiLiveAudioInterruptionSource) {
      (source as GeminiLiveAudioInterruptionSource).onMicrophoneInterrupted =
          _handleMicrophoneInterrupted;
    }
  }

  final GeminiLiveAudioAdapter _audioAdapter;
  final GeminiLiveOutboundSender _outboundSender;
  final bool Function() _isActive;
  final bool Function() _isTransportConnected;
  final bool Function() _isMuted;
  final void Function(String message) _onError;
  final void Function() _onUnavailable;
  final void Function()? _onMicrophoneInterrupted;
  bool _microphoneSuspended = false;
  bool _recording = false;
  int _microphoneGeneration = 0;
  Future<void> _microphoneQueue = Future<void>.value();
  Future<void> _microphoneStop = Future<void>.value();
  Future<bool>? _pendingResume;

  Future<bool> preparePlayback() async {
    if (!_isActive()) return false;

    final result = await _audioAdapter.preparePlayback();
    if (!_isActive()) return false;
    switch (result) {
      case GeminiLiveAudioPlaybackPrepareResult.ready:
      case GeminiLiveAudioPlaybackPrepareResult.unsupported:
        return true;
      case GeminiLiveAudioPlaybackPrepareResult.unavailable:
        _onError('오디오를 재생할 수 없습니다. 기기를 확인해주세요.');
        _onUnavailable();
        return false;
    }
  }

  Future<void> startRecording() async {
    if (!_isActive() || _microphoneSuspended) return;
    await _startWithDeadline(_microphoneGeneration, reportUnavailable: true);
  }

  Future<void> suspendMicrophone() async {
    final wasSuspended = _microphoneSuspended;
    _microphoneSuspended = true;
    _microphoneGeneration++;
    _recording = false;
    if (!wasSuspended && _isActive()) _onMicrophoneInterrupted?.call();
    try {
      await _stopMicrophone();
    } catch (error) {
      debugPrint('[GeminiLive] Microphone suspension failed: $error');
    }
  }

  Future<bool> resumeMicrophone() async {
    if (!_isActive() || !_isTransportConnected()) return false;
    final pending = _pendingResume;
    if (pending != null) return pending;
    _microphoneSuspended = false;
    final generation = ++_microphoneGeneration;
    final resuming = _startWithDeadline(generation, reportUnavailable: false);
    _pendingResume = resuming;
    try {
      return await resuming;
    } finally {
      if (identical(_pendingResume, resuming)) _pendingResume = null;
    }
  }

  Future<bool> _startWithDeadline(int generation,
      {required bool reportUnavailable}) async {
    final starting = _microphoneQueue.then((_) =>
        _startRecording(generation, reportUnavailable: reportUnavailable));
    // Serialize native starts. A timed-out start remains in this queue so a
    // late completion cannot stop a newer recording on the same recorder.
    _microphoneQueue = starting.then<void>((_) {}, onError: (Object _) {});
    try {
      return await starting.timeout(const Duration(seconds: 8));
    } catch (error) {
      if (_canRecord(generation)) {
        unawaited(suspendMicrophone());
        if (reportUnavailable) _onError('마이크를 시작하지 못했어요. 다시 연결해 주세요.');
      }
      return false;
    }
  }

  bool _canRecord(int generation) =>
      _isActive() &&
      !_microphoneSuspended &&
      generation == _microphoneGeneration;

  Future<bool> _startRecording(int generation,
      {required bool reportUnavailable}) async {
    if (!_canRecord(generation)) return false;
    await _microphoneStop;
    if (!_canRecord(generation)) return false;
    if (_recording) return true;

    final result = await _audioAdapter.startRecording(
      onData: _sendRecordedAudio,
    );
    if (!_canRecord(generation)) {
      if (result == GeminiLiveAudioStartResult.started) {
        // A native start can finish after end() already stopped the recorder.
        // Stop that late recording as well, without reviving UI callbacks.
        try {
          await _stopMicrophone();
        } catch (error) {
          debugPrint('[GeminiLive] Late recording cleanup failed: $error');
        }
      }
      return false;
    }

    switch (result) {
      case GeminiLiveAudioStartResult.started:
        _recording = true;
        return true;
      case GeminiLiveAudioStartResult.permissionDenied:
        _onError('마이크 권한이 필요합니다');
        break;
      case GeminiLiveAudioStartResult.permissionCheckFailed:
        break;
      case GeminiLiveAudioStartResult.unavailable:
        _onError('마이크를 사용할 수 없습니다. 기기를 확인해주세요.');
        if (reportUnavailable) _onUnavailable();
    }
    _microphoneSuspended = true;
    _onMicrophoneInterrupted?.call();
    return false;
  }

  void _handleMicrophoneInterrupted() {
    if (!_isActive() || _microphoneSuspended) return;
    unawaited(suspendMicrophone());
  }

  Future<void> stopRecording() {
    _microphoneSuspended = true;
    _microphoneGeneration++;
    _recording = false;
    return _stopMicrophone();
  }

  Future<void> _stopMicrophone() {
    final stopping = Future<void>.sync(_audioAdapter.stopRecording);
    final stopped =
        Future.wait<void>([_microphoneStop, stopping]).then<void>((_) {});
    _microphoneStop = stopped.then<void>((_) {}, onError: (Object _) {});
    return stopped;
  }

  void playBase64Pcm(String base64Data) {
    _audioAdapter.playBase64Pcm(base64Data);
  }

  Future<void> dispose() {
    _microphoneSuspended = true;
    _microphoneGeneration++;
    _recording = false;
    final source = _audioAdapter;
    if (source is GeminiLiveAudioInterruptionSource) {
      (source as GeminiLiveAudioInterruptionSource).onMicrophoneInterrupted =
          null;
    }
    return _audioAdapter.dispose();
  }

  void _sendRecordedAudio(Uint8List data) {
    if (!_isActive() ||
        _microphoneSuspended ||
        !_isTransportConnected() ||
        _isMuted()) {
      return;
    }
    _outboundSender.sendRealtimeAudio(data);
  }
}
