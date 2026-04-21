import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gemini_live_service.dart';
import 'voice_call_session_timer.dart';

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

class VoiceCallSessionResources {
  VoiceCallSessionResources(
    this._ringtone, {
    VoiceCallSessionTimer? timer,
  }) : _timer = timer ?? PeriodicVoiceCallSessionTimer();

  final VoiceCallRingtonePlayer _ringtone;
  final VoiceCallSessionTimer _timer;
  GeminiLiveService? _service;

  GeminiLiveService? get service => _service;

  List<TranscriptEntry> get transcript =>
      _service?.transcript ?? const <TranscriptEntry>[];

  void attachService(GeminiLiveService service) {
    _service = service;
  }

  void setMuted(bool isMuted) {
    _service?.isMuted = isMuted;
  }

  Future<void> playRingtone() async {
    try {
      await _ringtone.startLoop();
    } catch (e) {
      debugPrint('[VoiceCallSession] Ringtone play failed: $e');
    }
  }

  Future<void> stopRingtone() async {
    try {
      await _ringtone.stop();
    } catch (_) {}
  }

  void startTimer(void Function() onTick) {
    _timer.start(onTick);
  }

  void stopTimer() {
    _timer.stop();
  }

  Future<void> endService() async {
    await _service?.end();
  }

  Future<void> cancelActiveSession() async {
    stopTimer();
    await stopRingtone();
    final service = _service;
    _service = null;
    if (service == null) return;
    try {
      await service.dispose();
    } catch (e) {
      debugPrint('[VoiceCallSession] Service dispose failed: $e');
    }
  }

  Future<void> dispose() async {
    await cancelActiveSession();
    _timer.dispose();
    try {
      await _ringtone.dispose();
    } catch (_) {}
  }
}
