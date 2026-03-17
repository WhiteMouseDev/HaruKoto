import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../network/dio_client.dart';

class TtsService {
  static final TtsService _instance = TtsService._();
  factory TtsService() => _instance;
  TtsService._();

  final _player = AudioPlayer();
  final Map<String, String> _urlCache = {};
  final _dio = createDioClient();
  bool _playing = false;

  bool get isPlaying => _playing;

  Future<void> play(String vocabId) async {
    try {
      final url = await _fetchUrl(vocabId);
      if (url == null) return;
      _playing = true;
      await _player.stop();
      await _player.play(UrlSource(url));
      _player.onPlayerComplete.listen((_) {
        _playing = false;
      });
    } catch (e) {
      _playing = false;
      debugPrint('[TtsService] playback error: $e');
    }
  }

  void stop() {
    _player.stop();
    _playing = false;
  }

  Future<String?> _fetchUrl(String vocabId) async {
    if (_urlCache.containsKey(vocabId)) {
      return _urlCache[vocabId];
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/vocab/tts',
        data: {'id': vocabId},
      );
      final audioUrl = response.data?['audioUrl'] as String?;
      if (audioUrl != null) {
        _urlCache[vocabId] = audioUrl;
      }
      return audioUrl;
    } catch (e) {
      debugPrint('[TtsService] fetch TTS URL error: $e');
      return null;
    }
  }
}
