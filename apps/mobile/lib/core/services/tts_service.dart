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
    await _playUrl(() => _fetchVocabUrl(vocabId));
  }

  Future<void> playLessonScriptLine(String lessonId, int lineIndex) async {
    await _playUrl(() => _fetchLessonScriptLineUrl(lessonId, lineIndex));
  }

  /// Play TTS for arbitrary Japanese text (e.g. kana characters).
  Future<void> playText(String text) async {
    await _playUrl(() => _fetchKanaUrl(text));
  }

  /// Play audio from a direct URL (e.g. full dialogue audio).
  Future<void> playUrl(String url) async {
    await _playUrl(() async => url);
  }

  Future<void> _playUrl(Future<String?> Function() fetcher) async {
    try {
      final url = await fetcher();
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

  Future<String?> _fetchVocabUrl(String vocabId) async {
    if (_urlCache.containsKey('vocab:$vocabId')) {
      return _urlCache['vocab:$vocabId'];
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/vocab/tts',
        data: {'id': vocabId},
      );
      final audioUrl = response.data?['audioUrl'] as String?;
      if (audioUrl != null) {
        _urlCache['vocab:$vocabId'] = audioUrl;
      }
      return audioUrl;
    } catch (e) {
      debugPrint('[TtsService] fetch vocab TTS URL error: $e');
      return null;
    }
  }

  Future<String?> _fetchKanaUrl(String text) async {
    if (_urlCache.containsKey('kana:$text')) {
      return _urlCache['kana:$text'];
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/kana/tts',
        data: {'text': text},
      );
      final audioUrl = response.data?['audioUrl'] as String?;
      if (audioUrl != null) {
        _urlCache['kana:$text'] = audioUrl;
      }
      return audioUrl;
    } catch (e) {
      debugPrint('[TtsService] fetch kana TTS URL error: $e');
      return null;
    }
  }

  Future<String?> _fetchLessonScriptLineUrl(
      String lessonId, int lineIndex) async {
    final cacheKey = 'lesson-script:$lessonId:$lineIndex';
    if (_urlCache.containsKey(cacheKey)) {
      return _urlCache[cacheKey];
    }
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/lessons/$lessonId/script-lines/$lineIndex/tts',
      );
      final audioUrl = response.data?['audioUrl'] as String?;
      if (audioUrl != null) {
        _urlCache[cacheKey] = audioUrl;
      }
      return audioUrl;
    } catch (e) {
      debugPrint('[TtsService] fetch lesson script TTS URL error: $e');
      return null;
    }
  }
}
