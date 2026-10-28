import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:harukoto_mobile/core/services/tts_service.dart';

class FakeTtsPlayer implements TtsAudioPlayer {
  final events = StreamController<void>.broadcast(sync: true);
  final List<String> played = [];
  final List<String> audible = [];
  Completer<void>? preparation;
  Completer<void>? stopping;
  bool completeImmediately = false;
  bool stopFails = false;
  bool disposeFails = false;
  bool wantsPlayback = false;
  bool disposed = false;
  int stops = 0;

  @override
  Stream<void> get onComplete => events.stream;
  @override
  Future<void> playUrl(String url) async {
    played.add(url);
    wantsPlayback = true;
    await preparation?.future;
    // Models AudioPlayer's desiredState check after native source preparation.
    if (wantsPlayback && !disposed) {
      audible.add(url);
      if (completeImmediately) events.add(null);
    }
  }

  void complete() => events.add(null);
  void fail() => events.addError(StateError('native failure'));
  @override
  Future<void> stop() async {
    stops++;
    if (stopFails) throw StateError('stop failure');
    wantsPlayback = false;
    await stopping?.future;
  }

  @override
  Future<void> dispose() async {
    if (disposeFails) throw StateError('dispose failure');
    disposed = true;
    wantsPlayback = false;
  }
}

class TtsHarness {
  TtsHarness() {
    final dio = Dio();
    dio.httpClientAdapter = _TtsAdapter(this);
    service = TtsService.testing(
        createPlayer: () {
          final player = FakeTtsPlayer();
          configurePlayer?.call(player);
          players.add(player);
          return player;
        },
        dio: dio);
  }
  late final TtsService service;
  final players = <FakeTtsPlayer>[];
  final requests = <RequestOptions>[];
  Future<ResponseBody> Function(RequestOptions)? respond;
  void Function(FakeTtsPlayer)? configurePlayer;

  Future<void> dispose() async {
    await service.dispose();
    for (final player in players) {
      await player.events.close();
    }
  }
}

class _TtsAdapter implements HttpClientAdapter {
  _TtsAdapter(this.harness);
  final TtsHarness harness;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    harness.requests.add(options);
    if (harness.respond != null) return harness.respond!(options);
    return ResponseBody.fromString(
        jsonEncode({'audioUrl': 'https://audio.test${options.path}.mp3'}), 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });
  }

  @override
  void close({bool force = false}) {}
}

Future<void> flushTts() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
