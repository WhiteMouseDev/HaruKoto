import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_audio_adapter.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_service.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_transport.dart';

void main() {
  group('GeminiLiveService', () {
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

      await service.start();

      expect(transport.connectCalls, 1);
      expect(
        transport.lastUri.toString(),
        'wss://example.test/live?access_token=token/with/slash',
      );
      expect(states, [GeminiLiveState.connecting]);

      final setup = jsonDecode(transport.sent.single) as Map<String, dynamic>;
      expect((setup['setup'] as Map<String, dynamic>)['model'], 'gemini-live');

      transport.emitMessage('{"setupComplete":{}}');
      await Future<void>.delayed(Duration.zero);

      expect(states, [GeminiLiveState.connecting, GeminiLiveState.connected]);
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
  int startCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;
  final playedAudio = <String>[];
  void Function(Uint8List data)? _onData;

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
