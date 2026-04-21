import 'package:flutter/foundation.dart';

import '../data/gemini_live_service.dart';
import 'voice_call_ringtone_player.dart';
import 'voice_call_session_service_lifecycle.dart';
import 'voice_call_session_timer.dart';

export 'voice_call_ringtone_player.dart';

class VoiceCallSessionResources {
  VoiceCallSessionResources(
    this._ringtone, {
    VoiceCallSessionTimer? timer,
    VoiceCallSessionServiceLifecycle? serviceLifecycle,
  })  : _timer = timer ?? PeriodicVoiceCallSessionTimer(),
        _serviceLifecycle =
            serviceLifecycle ?? GeminiVoiceCallSessionServiceLifecycle();

  final VoiceCallRingtonePlayer _ringtone;
  final VoiceCallSessionTimer _timer;
  final VoiceCallSessionServiceLifecycle _serviceLifecycle;

  GeminiLiveService? get service => _serviceLifecycle.service;

  List<TranscriptEntry> get transcript => _serviceLifecycle.transcript;

  void attachService(GeminiLiveService service) {
    _serviceLifecycle.attach(service);
  }

  void setMuted(bool isMuted) {
    _serviceLifecycle.setMuted(isMuted);
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
    await _serviceLifecycle.end();
  }

  Future<void> cancelActiveSession() async {
    stopTimer();
    await stopRingtone();
    await _serviceLifecycle.disposeActive();
  }

  Future<void> dispose() async {
    await cancelActiveSession();
    _timer.dispose();
    try {
      await _ringtone.dispose();
    } catch (_) {}
  }
}
