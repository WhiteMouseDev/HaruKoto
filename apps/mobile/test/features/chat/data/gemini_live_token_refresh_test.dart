import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_audio_adapter.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_service.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_transport.dart';

void main() {
  group('Gemini Live token refresh', () {
    testWidgets('refreshes on every reconnect and preserves setup and mute',
        (tester) async {
      final transport = _FakeTransport();
      final firstToken = Completer<String>();
      var refreshCalls = 0;
      final service = _service(transport, () {
        refreshCalls++;
        return refreshCalls == 1
            ? firstToken.future
            : Future.value('fresh-$refreshCalls');
      });
      addTearDown(service.dispose);
      await _connect(tester, service, transport);
      final originalSetup = _setup(transport.sent.first);
      expect(originalSetup['inputAudioTranscription'], {
        'languageCodes': ['ja-JP', 'ko-KR'],
      });
      final realtimeConfig =
          originalSetup['realtimeInputConfig'] as Map<String, dynamic>;
      final activityDetection =
          realtimeConfig['automaticActivityDetection'] as Map<String, dynamic>;
      expect(
          activityDetection.containsKey('startOfSpeechSensitivity'), isFalse);
      service.isMuted = true;
      transport.emitResume('checkpoint-1');
      transport.emitGoAway();
      await tester.pump(const Duration(seconds: 1));

      expect(refreshCalls, 1);
      expect(transport.uris, hasLength(1));
      transport.emitResume('checkpoint-2');
      firstToken.complete('fresh-1');
      await tester.pump();

      expect(transport.uris.last.queryParameters['access_token'], 'fresh-1');
      expect(transport.uris.last.host, 'example.test');
      expect(_setup(transport.sent.last), {
        ...originalSetup,
        'sessionResumption': {'handle': 'checkpoint-2'},
      });
      transport.completeSetup();
      await tester.pump();
      expect(service.isMuted, isTrue);

      transport.disconnect();
      await tester.pump(const Duration(seconds: 1));
      expect(refreshCalls, 2);
      expect(transport.uris.last.queryParameters['access_token'], 'fresh-2');
      expect(_setup(transport.sent.last), {
        ...originalSetup,
        'sessionResumption': {'handle': 'checkpoint-2'},
      });
      transport.completeSetup();
      await tester.pump();
      final greetings = transport.sent.where((payload) =>
          (jsonDecode(payload) as Map<String, dynamic>)
              .containsKey('realtimeInput'));
      expect(greetings, hasLength(1));
      await service.end();
    });

    for (final dispose in [false, true]) {
      testWidgets('${dispose ? 'dispose' : 'end'} ignores a pending token',
          (tester) async {
        final transport = _FakeTransport();
        final pendingToken = Completer<String>();
        final service = _service(transport, () => pendingToken.future);
        final states = <GeminiLiveState>[];
        service.onStateChange = states.add;
        if (!dispose) addTearDown(service.dispose);
        await _connect(tester, service, transport);
        transport.emitResume('checkpoint');
        transport.disconnect();
        await tester.pump(const Duration(seconds: 1));

        if (dispose) {
          await service.dispose();
        } else {
          await service.end();
        }
        final stateCount = states.length;
        pendingToken.complete('arrived-after-call');
        await tester.pump();
        await tester.pump(const Duration(seconds: 20));

        expect(transport.uris, hasLength(1));
        expect(states, hasLength(stateCount));
      });
    }

    testWidgets('failed empty and hanging refreshes exhaust three attempts',
        (tester) async {
      final transport = _FakeTransport();
      final hangingToken = Completer<String>();
      var refreshCalls = 0;
      final service = _service(transport, () async {
        refreshCalls++;
        if (refreshCalls == 1) throw StateError('refresh unavailable');
        if (refreshCalls == 2) return '';
        return hangingToken.future;
      });
      addTearDown(service.dispose);
      final errors = <String>[];
      final states = <GeminiLiveState>[];
      service.onError = errors.add;
      service.onStateChange = states.add;
      await _connect(tester, service, transport);
      transport.disconnect();

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 4));
      expect(refreshCalls, 3);
      await tester.pump(const Duration(seconds: 10));

      expect(states.last, GeminiLiveState.error);
      expect(errors, ['연결이 끊어졌습니다']);
      expect(transport.uris, hasLength(1));
      hangingToken.complete('too-late');
      await tester.pump();
      await tester.pump(const Duration(seconds: 20));
      expect(refreshCalls, 3);
      expect(transport.uris, hasLength(1));
      await service.end();
    });

    testWidgets('timed out refresh cannot replace a later successful token',
        (tester) async {
      final transport = _FakeTransport();
      final expiredRequest = Completer<String>();
      final nextRequest = Completer<String>();
      var refreshCalls = 0;
      final service = _service(transport, () {
        refreshCalls++;
        return refreshCalls == 1 ? expiredRequest.future : nextRequest.future;
      });
      addTearDown(service.dispose);
      await _connect(tester, service, transport);
      transport.emitResume('checkpoint');
      transport.disconnect();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 2));
      expect(refreshCalls, 2);

      expiredRequest.complete('stale-token');
      await tester.pump();
      expect(transport.uris, hasLength(1));
      nextRequest.complete('current-token');
      await tester.pump();
      expect(transport.uris, hasLength(2));
      expect(
          transport.uris.last.queryParameters['access_token'], 'current-token');
      transport.completeSetup();
      await tester.pump();
      await service.end();
    });
  });
}

GeminiLiveService _service(
    _FakeTransport transport, Future<String> Function() refreshToken) {
  return GeminiLiveService(
    wsUri: 'wss://example.test/live',
    token: 'original-token',
    model: 'models/original-live',
    voiceName: 'Kore',
    systemInstruction: 'Original character and lesson context',
    refreshToken: refreshToken,
    transport: transport,
    audioAdapter: _FakeAudioAdapter(),
  );
}

Future<void> _connect(WidgetTester tester, GeminiLiveService service,
    _FakeTransport transport) async {
  final connecting = service.start();
  await tester.pump();
  expect(
      transport.uris.single.queryParameters['access_token'], 'original-token');
  transport.completeSetup();
  await tester.pump();
  await connecting;
}

Map<String, dynamic> _setup(String payload) =>
    (jsonDecode(payload) as Map<String, dynamic>)['setup']
        as Map<String, dynamic>;

class _FakeTransport implements GeminiLiveTransport {
  final uris = <Uri>[];
  final sent = <String>[];
  bool _connected = false;
  void Function(dynamic raw)? _onMessage;
  void Function()? _onDone;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect(Uri uri,
      {required void Function(dynamic raw) onMessage,
      required void Function(Object error) onError,
      required void Function() onDone}) async {
    uris.add(uri);
    _onMessage = onMessage;
    _onDone = onDone;
    _connected = true;
  }

  void completeSetup() => _onMessage?.call('{"setupComplete":{}}');

  void emitResume(String handle) => _onMessage?.call(jsonEncode({
        'sessionResumptionUpdate': {'resumable': true, 'newHandle': handle},
      }));

  void emitGoAway() => _onMessage?.call('{"goAway":{}}');

  void disconnect() {
    _connected = false;
    _onDone?.call();
  }

  @override
  void send(String data) => sent.add(data);

  @override
  Future<void> close() async => _connected = false;
}

class _FakeAudioAdapter implements GeminiLiveAudioAdapter {
  @override
  Future<GeminiLiveAudioPlaybackPrepareResult> preparePlayback() async =>
      GeminiLiveAudioPlaybackPrepareResult.ready;

  @override
  Future<GeminiLiveAudioStartResult> startRecording(
          {required void Function(Uint8List data) onData}) async =>
      GeminiLiveAudioStartResult.started;

  @override
  Future<void> stopRecording() async {}

  @override
  void playBase64Pcm(String base64Data) {}

  @override
  Future<void> dispose() async {}
}
