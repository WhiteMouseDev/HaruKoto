import 'dart:typed_data';

import 'gemini_live_audio_adapter.dart';
import 'gemini_live_outbound_sender.dart';

class GeminiLiveAudioSession {
  const GeminiLiveAudioSession({
    required GeminiLiveAudioAdapter audioAdapter,
    required GeminiLiveOutboundSender outboundSender,
    required bool Function() isActive,
    required bool Function() isTransportConnected,
    required bool Function() isMuted,
    required void Function(String message) onError,
    required void Function() onUnavailable,
  })  : _audioAdapter = audioAdapter,
        _outboundSender = outboundSender,
        _isActive = isActive,
        _isTransportConnected = isTransportConnected,
        _isMuted = isMuted,
        _onError = onError,
        _onUnavailable = onUnavailable;

  final GeminiLiveAudioAdapter _audioAdapter;
  final GeminiLiveOutboundSender _outboundSender;
  final bool Function() _isActive;
  final bool Function() _isTransportConnected;
  final bool Function() _isMuted;
  final void Function(String message) _onError;
  final void Function() _onUnavailable;

  Future<void> startRecording() async {
    if (!_isActive()) return;

    final result = await _audioAdapter.startRecording(
      onData: _sendRecordedAudio,
    );

    switch (result) {
      case GeminiLiveAudioStartResult.started:
        return;
      case GeminiLiveAudioStartResult.permissionDenied:
        _onError('마이크 권한이 필요합니다');
        return;
      case GeminiLiveAudioStartResult.permissionCheckFailed:
        return;
      case GeminiLiveAudioStartResult.unavailable:
        _onError('마이크를 사용할 수 없습니다. 기기를 확인해주세요.');
        _onUnavailable();
    }
  }

  Future<void> stopRecording() {
    return _audioAdapter.stopRecording();
  }

  void playBase64Pcm(String base64Data) {
    _audioAdapter.playBase64Pcm(base64Data);
  }

  Future<void> dispose() {
    return _audioAdapter.dispose();
  }

  void _sendRecordedAudio(Uint8List data) {
    if (!_isActive() || !_isTransportConnected() || _isMuted()) return;
    _outboundSender.sendRealtimeAudio(data);
  }
}
