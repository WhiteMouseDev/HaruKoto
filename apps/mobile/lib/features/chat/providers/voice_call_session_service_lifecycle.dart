import 'package:flutter/foundation.dart';

import '../data/gemini_live_service.dart';

abstract class VoiceCallSessionServiceLifecycle {
  GeminiLiveService? get service;
  List<TranscriptEntry> get transcript;

  void attach(GeminiLiveService service);
  void setMuted(bool isMuted);
  Future<void> end();
  Future<void> disposeActive();
}

class GeminiVoiceCallSessionServiceLifecycle
    implements VoiceCallSessionServiceLifecycle {
  GeminiLiveService? _service;

  @override
  GeminiLiveService? get service => _service;

  @override
  List<TranscriptEntry> get transcript =>
      _service?.transcript ?? const <TranscriptEntry>[];

  @override
  void attach(GeminiLiveService service) {
    _service = service;
  }

  @override
  void setMuted(bool isMuted) {
    _service?.isMuted = isMuted;
  }

  @override
  Future<void> end() async {
    await _service?.end();
  }

  @override
  Future<void> disposeActive() async {
    final service = _service;
    _service = null;
    if (service == null) return;
    try {
      await service.dispose();
    } catch (e) {
      debugPrint('[VoiceCallSession] Service dispose failed: $e');
    }
  }
}
