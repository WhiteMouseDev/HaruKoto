import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_audio_adapter.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_reconnect_coordinator.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_service.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_transport.dart';

void main() {
  group('GeminiLiveService', () {
    testWidgets('a silent greeting opens the mic after eight seconds once',
        (tester) async {
      final transport = _FakeGeminiLiveTransport();
      final audio = _FakeGeminiLiveAudioAdapter();
      final service = GeminiLiveService(
        wsUri: 'wss://example.test/live',
        token: 'token',
        model: 'gemini-live',
        transport: transport,
        audioAdapter: audio,
      );
      addTearDown(service.dispose);
      final starting = service.start();
      await tester.pump();
      transport.emitMessage('{"setupComplete":{}}');
      await tester.pump();
      await starting;
      expect(audio.startCalls, 0);
      await tester.pump(const Duration(seconds: 8));
      expect(audio.startCalls, 1);
      expect(transport.sent, hasLength(2)); // setup and one greeting only.
      transport.emitMessage('{"serverContent":{"turnComplete":true}}');
      await tester.pump();
      expect(audio.startCalls, 1);
      await service.end();
    });

    testWidgets('suspension survives greeting timeout and resumes explicitly',
        (tester) async {
      final transport = _FakeGeminiLiveTransport();
      final audio = _FakeGeminiLiveAudioAdapter();
      final service = GeminiLiveService(
        wsUri: 'wss://example.test/live',
        token: 'token',
        model: 'gemini-live',
        transport: transport,
        audioAdapter: audio,
      );
      addTearDown(service.dispose);
      var interruptions = 0;
      service.onMicrophoneInterrupted = () => interruptions++;
      final starting = service.start();
      await tester.pump();
      transport.emitMessage('{"setupComplete":{}}');
      await tester.pump();
      await starting;
      service.isMuted = true;
      await service.suspendMicrophone();
      await tester.pump(const Duration(seconds: 8));
      transport.emitMessage('{"serverContent":{"turnComplete":true}}');
      await tester.pump();
      expect(audio.startCalls, 0);
      expect(interruptions, 1);
      expect(await service.resumeMicrophone(), isTrue);
      expect(audio.startCalls, 1);
      expect(service.isMuted, isTrue);
      await service.end();
      expect(await service.resumeMicrophone(), isFalse);
    });

    testWidgets('blocks mic audio until the resumed setup is complete',
        (tester) async {
      final transport = _FakeGeminiLiveTransport();
      final audioAdapter = _FakeGeminiLiveAudioAdapter();
      final service = GeminiLiveService(
        wsUri: 'wss://example.test/live',
        token: 'token',
        model: 'gemini-live',
        transport: transport,
        audioAdapter: audioAdapter,
      );
      addTearDown(service.dispose);
      final connecting = service.start();
      await tester.pump();
      transport.emitMessage('{"setupComplete":{}}');
      await tester.pump();
      await connecting;
      transport.emitMessage('{"serverContent":{"turnComplete":true}}');
      await tester.pump();
      transport.emitMessage(
          '{"sessionResumptionUpdate":{"resumable":true,"newHandle":"resume-1"}}');
      transport.emitMessage('{"goAway":{}}');

      final beforeReconnect = transport.sent.length;
      audioAdapter.emitRecordedAudio(Uint8List.fromList([1, 2]));
      expect(transport.sent, hasLength(beforeReconnect));

      await tester.pump(const Duration(seconds: 1));
      expect(transport.connectCalls, 2);
      final beforeSetupComplete = transport.sent.length;
      audioAdapter.emitRecordedAudio(Uint8List.fromList([3, 4]));
      expect(transport.sent, hasLength(beforeSetupComplete));

      transport.emitMessage('{"setupComplete":{}}');
      await tester.pump();
      audioAdapter.emitRecordedAudio(Uint8List.fromList([5, 6]));
      expect(transport.sent, hasLength(beforeSetupComplete + 1));
      final payload = jsonDecode(transport.sent.last) as Map<String, dynamic>;
      final input = payload['realtimeInput'] as Map<String, dynamic>;
      expect((input['audio'] as Map<String, dynamic>)['data'],
          base64Encode([5, 6]));
      expect(audioAdapter.startCalls, 1);
      await service.end();
    });

    test('help uses the current session and preserves mute and transcript',
        () async {
      final transport = _FakeGeminiLiveTransport();
      final reconnectCoordinator = GeminiLiveReconnectCoordinator();
      final service = GeminiLiveService(
        wsUri: 'wss://example.test/live',
        token: 'token',
        model: 'gemini-live',
        transport: transport,
        audioAdapter: _FakeGeminiLiveAudioAdapter(),
        reconnectCoordinator: reconnectCoordinator,
      );
      expect(await service.requestHelp(GeminiLiveHelpAction.repeat), isFalse);
      final connecting = service.start();
      await Future<void>.delayed(Duration.zero);
      expect(await service.requestHelp(GeminiLiveHelpAction.repeat), isFalse);
      transport.emitMessage('{"setupComplete":{}}');
      await connecting;
      service.isMuted = true;

      expect(
        await service.requestHelp(
          GeminiLiveHelpAction.meaning,
          targetText: '何名様ですか。',
        ),
        isTrue,
      );
      final payload = jsonDecode(transport.sent.last) as Map<String, dynamic>;
      final input = payload['realtimeInput'] as Map<String, dynamic>;
      expect(input['text'], contains('何名様ですか。'));
      expect(input['text'], contains('韓国語'));
      expect(service.isMuted, isTrue);
      expect(service.transcript, isEmpty);

      reconnectCoordinator.requestReconnect();
      final beforeReconnectHelp = transport.sent.length;
      expect(await service.requestHelp(GeminiLiveHelpAction.repeat), isFalse);
      expect(transport.sent, hasLength(beforeReconnectHelp));

      await service.end();
      final sentCount = transport.sent.length;
      expect(
          await service.requestHelp(GeminiLiveHelpAction.replyHint), isFalse);
      expect(transport.sent, hasLength(sentCount));
    });

    test('start sends setup and setupComplete starts greeting and recording',
        () async {
      final transport = _FakeGeminiLiveTransport();
      final audioAdapter = _FakeGeminiLiveAudioAdapter();
      final service = GeminiLiveService(
        wsUri: 'wss://example.test/live',
        token: 'token/with/slash',
        model: 'gemini-live',
        characterName: 'ハル',
        scenarioGreeting: 'カスタム挨拶',
        userNickname: 'Tester',
        audioAdapter: audioAdapter,
        transport: transport,
      );
      final states = <GeminiLiveState>[];
      service.onStateChange = states.add;

      final connecting = service.start();
      await Future<void>.delayed(Duration.zero);

      expect(transport.connectCalls, 1);
      expect(
        transport.lastUri.toString(),
        'wss://example.test/live?access_token=token/with/slash',
      );
      expect(states, [GeminiLiveState.connecting]);

      final setup = jsonDecode(transport.sent.single) as Map<String, dynamic>;
      expect((setup['setup'] as Map<String, dynamic>)['model'], 'gemini-live');

      transport.emitMessage('{"setupComplete":{}}');
      await connecting;
      await Future<void>.delayed(Duration.zero);

      expect(states, [GeminiLiveState.connecting, GeminiLiveState.connected]);
      expect(audioAdapter.prepareCalls, 1);
      expect(audioAdapter.startCalls, 0);
      expect(transport.sent, hasLength(2));

      final greeting = jsonDecode(transport.sent[1]) as Map<String, dynamic>;
      final greetingInput = greeting['realtimeInput'] as Map<String, dynamic>;
      expect(greetingInput['text'], 'カスタム挨拶');

      transport.emitMessage('{"serverContent":{"turnComplete":true}}');
      await Future<void>.delayed(Duration.zero);

      expect(audioAdapter.startCalls, 1);

      audioAdapter.emitRecordedAudio(Uint8List.fromList([1, 2, 3]));

      final audio = jsonDecode(transport.sent[2]) as Map<String, dynamic>;
      final realtimeInput = audio['realtimeInput'] as Map<String, dynamic>;
      final chunk = realtimeInput['audio'] as Map<String, dynamic>;
      expect(chunk['mimeType'], 'audio/pcm;rate=16000');
      expect(chunk['data'], base64Encode([1, 2, 3]));

      await service.end();

      expect(audioAdapter.stopCalls, 1);
      expect(transport.closeCalls, 1);
      expect(states, [
        GeminiLiveState.connecting,
        GeminiLiveState.connected,
        GeminiLiveState.ending,
        GeminiLiveState.ended,
      ]);
    });

    test('start reports an error without connecting when model is empty',
        () async {
      final transport = _FakeGeminiLiveTransport();
      final service = GeminiLiveService(
        wsUri: 'wss://example.test/live',
        token: 'token',
        model: '',
        transport: transport,
        audioAdapter: _FakeGeminiLiveAudioAdapter(),
      );
      final states = <GeminiLiveState>[];
      final errors = <String>[];
      service.onStateChange = states.add;
      service.onError = errors.add;

      await service.start();

      expect(transport.connectCalls, 0);
      expect(errors, ['음성 모델이 설정되지 않았습니다']);
      expect(states, [GeminiLiveState.error]);
    });
  });
}

class _FakeGeminiLiveTransport implements GeminiLiveTransport {
  int connectCalls = 0;
  int closeCalls = 0;
  Uri? lastUri;
  final sent = <String>[];
  void Function(dynamic raw)? _onMessage;
  void Function(Object error)? _onError;
  void Function()? _onDone;
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect(
    Uri uri, {
    required void Function(dynamic raw) onMessage,
    required void Function(Object error) onError,
    required void Function() onDone,
  }) async {
    connectCalls++;
    lastUri = uri;
    _onMessage = onMessage;
    _onError = onError;
    _onDone = onDone;
    _connected = true;
  }

  @override
  void send(String data) {
    sent.add(data);
  }

  void emitMessage(dynamic raw) {
    _onMessage?.call(raw);
  }

  void emitError(Object error) {
    _onError?.call(error);
  }

  void emitDone() {
    _connected = false;
    _onDone?.call();
  }

  @override
  Future<void> close() async {
    closeCalls++;
    _connected = false;
  }
}

class _FakeGeminiLiveAudioAdapter implements GeminiLiveAudioAdapter {
  int prepareCalls = 0;
  int startCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;
  final playedAudio = <String>[];
  void Function(Uint8List data)? _onData;

  @override
  Future<GeminiLiveAudioPlaybackPrepareResult> preparePlayback() async {
    prepareCalls++;
    return GeminiLiveAudioPlaybackPrepareResult.ready;
  }

  @override
  Future<GeminiLiveAudioStartResult> startRecording({
    required void Function(Uint8List data) onData,
  }) async {
    startCalls++;
    _onData = onData;
    return GeminiLiveAudioStartResult.started;
  }

  void emitRecordedAudio(Uint8List data) {
    _onData?.call(data);
  }

  @override
  Future<void> stopRecording() async {
    stopCalls++;
  }

  @override
  void playBase64Pcm(String base64Data) {
    playedAudio.add(base64Data);
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}
