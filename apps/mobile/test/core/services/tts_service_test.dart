import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/services/tts_service.dart';

import '../../fixtures/fake_tts.dart';

void main() {
  late TtsHarness h;
  setUp(() => h = TtsHarness());
  tearDown(() => h.dispose());

  test(
      'four lines start in order only after real completion, with one request each',
      () async {
    final run =
        h.service.playLessonDialogue('lesson', [0, 1, 2, 3], owner: Object());
    await flushTts();
    expect(
        h.requests.map((r) => r.path), ['/lessons/lesson/script-lines/0/tts']);
    expect(h.players, hasLength(1));
    for (var index = 0; index < 4; index++) {
      expect(h.service.playback.value.lineIndex, index);
      expect(h.players[index].audible, hasLength(1));
      h.players[index].complete();
      await flushTts();
      expect(h.requests, hasLength(index == 3 ? 4 : index + 2));
    }
    await run;
    expect(h.service.playback.value.phase, TtsPlaybackPhase.completed);
    expect(h.service.playback.value.lineIndex, isNull);
    expect(h.players.every((p) => p.disposed), isTrue);
  });

  test('stop during lookup finishes queue and late URL cannot start any player',
      () async {
    final response = Completer<ResponseBody>();
    h.respond = (_) => response.future;
    final owner = Object();
    final run = h.service.playLessonDialogue('lesson', [0, 1], owner: owner);
    await flushTts();
    h.service.stop(owner: owner);
    await run;
    response.complete(_audioResponse('https://audio.test/late.mp3'));
    await flushTts();
    expect(h.players, isEmpty);
    expect(h.requests, hasLength(1));
    expect(h.service.playback.value.phase, TtsPlaybackPhase.idle);
  });

  test('stop during native preparation prevents an audible start after exit',
      () async {
    final preparation = Completer<void>();
    h.configurePlayer = (p) => p.preparation = preparation;
    final run = h.service.playLessonDialogue('lesson', [0, 1], owner: Object());
    await flushTts();
    expect(h.players.single.played, hasLength(1));
    h.service.stop(lessonId: 'lesson');
    expect(h.players.single.wantsPlayback, isFalse);
    await run;
    preparation.complete();
    await flushTts();
    expect(h.players.single.audible, isEmpty);
    expect(h.requests, hasLength(1));
  });

  test('replay restarts at first line and reuses URLs', () async {
    final owner = Object();
    final first = h.service.playLessonDialogue('lesson', [0, 1], owner: owner);
    await flushTts();
    h.players.first.complete();
    await flushTts();
    h.service.stop(owner: owner);
    await first;
    final replay = h.service.playLessonDialogue('lesson', [0, 1], owner: owner);
    await flushTts();
    expect(h.players.last.played.single, contains('/script-lines/0/tts'));
    expect(h.requests, hasLength(2));
    h.service.stop();
    await replay;
  });

  test(
      'manual sentence supersedes pending whole lookup and old owner cannot stop it',
      () async {
    final oldResponse = Completer<ResponseBody>();
    h.respond = (options) => options.path.contains('/0/')
        ? oldResponse.future
        : Future.value(_audioResponse('https://audio.test/manual.mp3'));
    final queueOwner = Object();
    final run =
        h.service.playLessonDialogue('lesson', [0, 1], owner: queueOwner);
    await flushTts();
    await h.service.playLessonScriptLine('lesson', 3, owner: Object());
    await run;
    h.service.stop(owner: queueOwner);
    oldResponse.complete(_audioResponse('https://audio.test/stale.mp3'));
    await flushTts();
    expect(h.players.single.audible, ['https://audio.test/manual.mp3']);
    expect(h.service.playback.value.phase, TtsPlaybackPhase.playing);
  });

  test('pending single lookup cannot overwrite a newer queue', () async {
    final oldResponse = Completer<ResponseBody>();
    h.respond = (options) => options.path == '/vocab/tts'
        ? oldResponse.future
        : Future.value(_audioResponse('https://audio.test/current.mp3'));
    final old = h.service.play('vocab');
    await flushTts();
    final run = h.service.playLessonDialogue('lesson', [0], owner: Object());
    await flushTts();
    oldResponse.complete(_audioResponse('https://audio.test/stale.mp3'));
    await old;
    await flushTts();
    expect(h.players.single.audible, ['https://audio.test/current.mp3']);
    h.players.single.complete();
    await run;
  });

  test(
      'late old-source completion and error cannot advance or fail new playback',
      () async {
    final owner = Object();
    final first = h.service.playLessonDialogue('lesson', [0, 1], owner: owner);
    await flushTts();
    final oldPlayer = h.players.single;
    h.service.stop(owner: owner);
    await first;
    final second = h.service.playLessonDialogue('lesson', [0, 1], owner: owner);
    await flushTts();
    oldPlayer.complete();
    // Retired streams have no listener; avoid an unhandled broadcast error.
    final ignored =
        oldPlayer.events.stream.listen((_) {}, onError: (Object _) {});
    oldPlayer.fail();
    await flushTts();
    expect(h.players, hasLength(2));
    expect(h.service.playback.value.phase, TtsPlaybackPhase.playing);
    expect(h.service.playback.value.lineIndex, 0);
    await ignored.cancel();
    h.service.stop();
    await second;
  });

  test(
      'a failed line stops the queue; retry starts at first line without skipping',
      () async {
    var fail = true;
    h.respond = (options) async {
      if (fail && options.path.contains('/1/')) {
        return ResponseBody.fromString('{}', 503);
      }
      return _audioResponse('https://audio.test${options.path}.mp3');
    };
    final owner = Object();
    final first =
        h.service.playLessonDialogue('lesson', [0, 1, 2], owner: owner);
    await flushTts();
    h.players.single.complete();
    await first;
    expect(h.service.playback.value.phase, TtsPlaybackPhase.failed);
    expect(h.service.playback.value.error?.userMessage, contains('서버 오류'));
    expect(h.requests, hasLength(2));
    fail = false;
    final retry =
        h.service.playLessonDialogue('lesson', [0, 1, 2], owner: owner);
    await flushTts();
    expect(h.players.last.played.single, contains('/script-lines/0/tts'));
    h.service.stop();
    await retry;
  });

  test(
      'native error cancels pending prepare; resolving it cannot play after failure',
      () async {
    final preparation = Completer<void>();
    h.configurePlayer = (p) => p.preparation = preparation;
    final run = h.service.playLessonDialogue('lesson', [0, 1], owner: Object());
    await flushTts();
    h.players.single.fail();
    await run;
    preparation.complete();
    await flushTts();
    expect(h.service.playback.value.phase, TtsPlaybackPhase.failed);
    expect(h.players.single.audible, isEmpty);
    expect(h.requests, hasLength(1));
  });

  test('immediate completion during play is not lost', () async {
    h.configurePlayer = (p) => p.completeImmediately = true;
    await h.service.playLessonDialogue('lesson', [0, 1], owner: Object());
    expect(h.players, hasLength(2));
    expect(h.service.playback.value.phase, TtsPlaybackPhase.completed);
  });

  test(
      'new sound waits for old stop; successful dispose recovers a stop failure',
      () async {
    await h.service.playUrl('https://audio.test/one.mp3');
    final stopped = Completer<void>();
    h.players.first.stopping = stopped;
    final next = h.service.playUrl('https://audio.test/two.mp3');
    await flushTts();
    expect(h.players, hasLength(1));
    stopped.complete();
    await next;
    expect(h.players.last.audible, ['https://audio.test/two.mp3']);
    h.players.last.stopFails = true;
    await h.service.playUrl('https://audio.test/three.mp3');
    expect(h.players.last.audible, ['https://audio.test/three.mp3']);
  });

  test(
      'both stop and dispose failing blocks overlapping sound and reports an error',
      () async {
    await h.service.playUrl('https://audio.test/one.mp3');
    h.players.first.stopFails = true;
    h.players.first.disposeFails = true;
    await h.service.playUrl('https://audio.test/two.mp3');
    expect(h.players, hasLength(1));
    expect(h.service.playback.value.phase, TtsPlaybackPhase.failed);
    expect(h.service.playback.value.error?.userMessage, contains('앱을 다시'));
  });

  test(
      'retired sentence events cannot skip the next sentence in the same queue',
      () async {
    final run =
        h.service.playLessonDialogue('lesson', [0, 1, 2], owner: Object());
    await flushTts();
    final old = h.players.first;
    old.complete();
    await flushTts();
    expect(h.service.playback.value.lineIndex, 1);
    final ignored = old.events.stream.listen((_) {}, onError: (Object _) {});
    old.complete();
    old.fail();
    await flushTts();
    expect(h.players, hasLength(2));
    expect(h.service.playback.value.lineIndex, 1);
    expect(h.service.playback.value.phase, TtsPlaybackPhase.playing);
    await ignored.cancel();
    h.service.stop();
    await run;
  });

  test(
      'cancelling while old cleanup is pending finishes without bypassing the safety gate',
      () async {
    await h.service.playUrl('https://audio.test/old.mp3');
    final stopping = Completer<void>();
    h.players.first.stopping = stopping;
    final owner = Object();
    final run = h.service.playLessonDialogue('lesson', [0, 1], owner: owner);
    await flushTts();
    h.service.stop(owner: owner);
    var finished = false;
    unawaited(run.then((_) => finished = true));
    await flushTts();
    expect(finished, isTrue);
    expect(h.players, hasLength(1));
    stopping.complete();
    await flushTts();
    expect(h.players, hasLength(1));
  });

  test(
      'legacy vocab, kana and direct URL single playback still returns after start',
      () async {
    await h.service.play('vocab');
    expect(h.service.isPlaying, isTrue);
    await h.service.playText('あ');
    expect(h.service.isPlaying, isTrue);
    await h.service.playUrl('https://audio.test/direct.mp3');
    expect(h.service.isPlaying, isTrue);
    expect(h.requests.map((r) => r.path), ['/vocab/tts', '/kana/tts']);
  });
}

ResponseBody _audioResponse(String url) =>
    ResponseBody.fromString(jsonEncode({'audioUrl': url}), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
