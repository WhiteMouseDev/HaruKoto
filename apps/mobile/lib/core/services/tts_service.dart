import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../network/api_exception.dart';
import '../network/dio_client.dart';

enum TtsPlaybackPhase { idle, loading, playing, completed, failed }

@immutable
class TtsPlaybackState {
  const TtsPlaybackState({
    this.phase = TtsPlaybackPhase.idle,
    this.owner,
    this.lessonId,
    this.lineIndex,
    this.totalLines,
    this.isDialogue = false,
    this.error,
  });

  final TtsPlaybackPhase phase;
  final Object? owner;
  final String? lessonId;
  final int? lineIndex;
  final int? totalLines;
  final bool isDialogue;
  final ApiException? error;
  bool get isActive =>
      phase == TtsPlaybackPhase.loading || phase == TtsPlaybackPhase.playing;
}

/// Keeps native completion/preparation races reproducible in tests.
abstract interface class TtsAudioPlayer {
  Stream<void> get onComplete;
  Future<void> playUrl(String url);
  Future<void> stop();
  Future<void> dispose();
}

class _DeviceTtsAudioPlayer implements TtsAudioPlayer {
  final AudioPlayer _player = AudioPlayer();
  @override
  Stream<void> get onComplete => _player.onPlayerComplete;
  @override
  Future<void> playUrl(String url) => _player.play(UrlSource(url));
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> dispose() => _player.dispose();
}

class _PlaybackRun {
  _PlaybackRun(
      {required this.owner,
      required this.isDialogue,
      this.lessonId,
      this.totalLines});
  final Object owner;
  final bool isDialogue;
  final String? lessonId;
  final int? totalLines;
  final cancelled = Completer<void>();
}

class _ActiveLine {
  _ActiveLine(this.run, this.player);
  final _PlaybackRun run;
  final TtsAudioPlayer player;
  final completion = Completer<void>();
  // Owned and cancelled by TtsService._retireLine on completion or cancellation.
  // ignore: cancel_subscriptions
  StreamSubscription<void>? subscription;
}

class TtsService {
  static final TtsService _instance = TtsService._();
  factory TtsService() => _instance;
  TtsService._() : _createPlayer = _DeviceTtsAudioPlayer.new;

  @visibleForTesting
  TtsService.testing(
      {required TtsAudioPlayer Function() createPlayer, required Dio dio})
      : _createPlayer = createPlayer,
        _client = dio;

  // Rendering controls must not initialize native audio or authentication.
  final TtsAudioPlayer Function() _createPlayer;
  Dio? _client;
  Dio get _dio => _client ??= createDioClient();
  final Map<String, String> _urlCache = {};
  final ValueNotifier<TtsPlaybackState> _playback =
      ValueNotifier(const TtsPlaybackState());
  ValueListenable<TtsPlaybackState> get playback => _playback;
  _PlaybackRun? _run;
  _ActiveLine? _activeLine;
  Future<ApiException?> _stoppingAudio = Future<ApiException?>.value();
  final Set<Future<void>> _cleanups = {};
  bool _disposed = false;

  bool get isPlaying => _playback.value.phase == TtsPlaybackPhase.playing;

  Future<void> play(String vocabId, {Object? owner}) =>
      _playSingle(() => _fetchVocabUrl(vocabId), owner: owner);

  Future<void> playLessonScriptLine(String lessonId, int lineIndex,
          {Object? owner}) =>
      _playSingle(() => _fetchLessonScriptLineUrl(lessonId, lineIndex),
          owner: owner, lessonId: lessonId, lineIndex: lineIndex);

  Future<void> playText(String text, {Object? owner}) =>
      _playSingle(() => _fetchKanaUrl(text), owner: owner);

  Future<void> playUrl(String url, {Object? owner, String? lessonId}) =>
      _playSingle(() async => url, owner: owner, lessonId: lessonId);

  /// Looks up only the current sentence and waits for actual completion.
  /// Explicit start/retry always begins at the first supplied sentence index.
  Future<void> playLessonDialogue(String lessonId, List<int> lineIndices,
      {required Object owner}) async {
    if (_disposed || lineIndices.isEmpty) return;
    final indices = List<int>.unmodifiable(lineIndices);
    final run = _begin(
        owner: owner,
        lessonId: lessonId,
        isDialogue: true,
        totalLines: indices.length);
    try {
      for (final index in indices) {
        if (!_isCurrent(run)) return;
        _publish(run, TtsPlaybackPhase.loading, lineIndex: index);
        final line = await _startLine(
            run, () => _fetchLessonScriptLineUrl(lessonId, index), index);
        if (!_isCurrent(run) || line == null) return;
        await line.completion.future;
      }
      if (_isCurrent(run)) _publish(run, TtsPlaybackPhase.completed);
    } catch (error) {
      _fail(run, error);
    }
  }

  // Existing single-item callers still return after playback starts.
  Future<void> _playSingle(Future<String?> Function() fetcher,
      {Object? owner, String? lessonId, int? lineIndex}) async {
    if (_disposed) return;
    final run =
        _begin(owner: owner ?? Object(), lessonId: lessonId, isDialogue: false);
    _publish(run, TtsPlaybackPhase.loading, lineIndex: lineIndex);
    try {
      await _startLine(run, fetcher, lineIndex);
    } catch (error) {
      _fail(run, error);
    }
  }

  _PlaybackRun _begin(
      {required Object owner,
      required bool isDialogue,
      String? lessonId,
      int? totalLines}) {
    _cancelRun();
    final run = _PlaybackRun(
        owner: owner,
        lessonId: lessonId,
        isDialogue: isDialogue,
        totalLines: totalLines);
    _run = run;
    return run;
  }

  Future<_ActiveLine?> _startLine(_PlaybackRun run,
      Future<String?> Function() fetcher, int? lineIndex) async {
    final url = await Future.any<String?>([
      fetcher(),
      run.cancelled.future.then((_) => null),
    ]);
    if (!_isCurrent(run)) return null;
    if (url == null || url.trim().isEmpty) {
      throw const ApiException(message: '음성을 불러오지 못했어요. 다시 시도해 주세요.');
    }
    final releaseFailure = await Future.any<ApiException?>([
      _stoppingAudio,
      run.cancelled.future.then((_) => null),
    ]);
    if (!_isCurrent(run)) return null;
    if (releaseFailure != null) throw releaseFailure;
    // Each sentence has its own native player/event stream. A late completion
    // or error from a retired source cannot advance or fail the new sentence.
    final line = _ActiveLine(run, _createPlayer());
    _activeLine = line;
    line.subscription = line.player.onComplete.listen(
      (_) => _onComplete(line),
      onError: (Object error) {
        if (identical(_activeLine, line)) _fail(run, error);
      },
    );
    // The waiter and subscription exist before play, including very short files.
    await Future.any<void>([
      line.player.playUrl(url),
      run.cancelled.future,
    ]);
    if (_isCurrent(run) && identical(_activeLine, line)) {
      _publish(run, TtsPlaybackPhase.playing, lineIndex: lineIndex);
    }
    return _isCurrent(run) ? line : null;
  }

  bool _isCurrent(_PlaybackRun run) =>
      !_disposed && identical(_run, run) && !run.cancelled.isCompleted;

  void _publish(_PlaybackRun run, TtsPlaybackPhase phase,
      {int? lineIndex, ApiException? error}) {
    if (!_isCurrent(run)) return;
    _playback.value = TtsPlaybackState(
        phase: phase,
        owner: run.owner,
        lessonId: run.lessonId,
        lineIndex: lineIndex,
        totalLines: run.totalLines,
        isDialogue: run.isDialogue,
        error: error);
  }

  void _onComplete(_ActiveLine line) {
    if (!identical(_activeLine, line) || !_isCurrent(line.run)) return;
    _retireLine(line);
    if (!line.run.isDialogue) {
      _publish(line.run, TtsPlaybackPhase.completed);
    }
  }

  void _fail(_PlaybackRun run, Object error) {
    if (!_isCurrent(run)) return;
    final failure = error is ApiException
        ? error
        : error is DioException
            ? ApiException.fromDioException(error)
            : const ApiException(message: '음성을 재생하지 못했어요. 다시 시도해 주세요.');
    _publish(run, TtsPlaybackPhase.failed,
        lineIndex: _playback.value.lineIndex, error: failure);
    _cancelRun();
    debugPrint('[TtsService] playback failed');
  }

  void _cancelRun() {
    final run = _run;
    _run = null;
    if (run != null && !run.cancelled.isCompleted) run.cancelled.complete();
    final line = _activeLine;
    if (line != null) _retireLine(line);
  }

  void _retireLine(_ActiveLine line) {
    if (!identical(_activeLine, line)) return;
    _activeLine = null;
    if (!line.completion.isCompleted) line.completion.complete();
    // AudioPlayer.stop changes desiredState synchronously, before the pending
    // source preparation can resume. Never queue this call behind play().
    final stopped = () async {
      try {
        await line.player.stop();
        return true;
      } catch (_) {
        debugPrint('[TtsService] stop failed');
        return false;
      }
    }();
    final released = () async {
      try {
        await line.subscription?.cancel();
      } catch (_) {
        debugPrint('[TtsService] completion cleanup failed');
      }
      final didStop = await stopped;
      var didDispose = false;
      try {
        await line.player.dispose();
        didDispose = true;
      } catch (_) {
        debugPrint('[TtsService] dispose failed');
      }
      if (didStop || didDispose) return null;
      const failure =
          ApiException(message: '이전 음성을 정리하지 못했어요. 앱을 다시 연 뒤 시도해 주세요.');
      if (!_disposed &&
          _run == null &&
          _playback.value.phase == TtsPlaybackPhase.idle) {
        _playback.value = TtsPlaybackState(
            phase: TtsPlaybackPhase.failed,
            owner: line.run.owner,
            lessonId: line.run.lessonId,
            isDialogue: line.run.isDialogue,
            error: failure);
      }
      return failure;
    }();
    // Do not permit a second audible player if both stop and disposal failed.
    _stoppingAudio = Future.wait<ApiException?>([_stoppingAudio, released])
        .then((results) =>
            results.firstWhere((error) => error != null, orElse: () => null));
    final cleanup = released.then<void>((_) {});
    _cleanups.add(cleanup);
    unawaited(cleanup.whenComplete(() => _cleanups.remove(cleanup)));
  }

  /// Owner guards keep an outgoing widget from stopping a newer screen's audio.
  void stop({Object? owner, String? lessonId}) {
    if (_disposed) return;
    if (owner != null && !identical(_run?.owner, owner)) return;
    if (lessonId != null && _run?.lessonId != lessonId) return;
    _cancelRun();
    _playback.value = const TtsPlaybackState();
  }

  @visibleForTesting
  Future<void> dispose() async {
    stop();
    _disposed = true;
    await Future.wait(_cleanups);
    _playback.dispose();
  }

  Future<String?> _cachedUrl(
      String key, Future<String?> Function() fetch) async {
    if (_urlCache.containsKey(key)) return _urlCache[key];
    final url = await fetch();
    if (url != null && url.trim().isNotEmpty) _urlCache[key] = url;
    return url;
  }

  Future<String?> _fetchVocabUrl(String vocabId) =>
      _cachedUrl('vocab:$vocabId', () async {
        final response = await _dio
            .post<Map<String, dynamic>>('/vocab/tts', data: {'id': vocabId});
        return response.data?['audioUrl'] as String?;
      });

  Future<String?> _fetchKanaUrl(String text) =>
      _cachedUrl('kana:$text', () async {
        final response = await _dio
            .post<Map<String, dynamic>>('/kana/tts', data: {'text': text});
        return response.data?['audioUrl'] as String?;
      });

  Future<String?> _fetchLessonScriptLineUrl(String lessonId, int lineIndex) =>
      _cachedUrl('lesson-script:$lessonId:$lineIndex', () async {
        final response = await _dio.post<Map<String, dynamic>>(
            '/lessons/$lessonId/script-lines/$lineIndex/tts');
        return response.data?['audioUrl'] as String?;
      });
}
