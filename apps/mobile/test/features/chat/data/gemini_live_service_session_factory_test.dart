import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_audio_adapter.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_events.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_service_session_factory.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_transport.dart';

void main() {
  group('GeminiLiveServiceSessionFactory', () {
    test('builds a service session that wires runtime and lifecycle delegates',
        () async {
      final transport = _FakeGeminiLiveTransport();
      final audioAdapter = _FakeGeminiLiveAudioAdapter();
      final states = <GeminiLiveState>[];
      final aiTexts = <String>[];
      final transcriptEntries = <String>[];
      final errors = <String>[];
      final session = const GeminiLiveServiceSessionFactory().build(
        wsUri: 'wss://example.test/live',
        token: 'token',
        model: 'gemini-live',
        userNickname: 'Tester',
        silenceDurationMs: 900,
        jlptLevel: 'N3',
        characterName: 'ハル',
        scenarioGreeting: 'カスタム挨拶',
        audioAdapter: audioAdapter,
        transport: transport,
        emitState: states.add,
        emitAiTextDelta: aiTexts.add,
        emitTranscriptEntry: (entry) {
          transcriptEntries.add('${entry.role}:${entry.text}');
        },
        emitError: errors.add,
      );

      await session.lifecycleRunner.start(model: 'gemini-live');

      expect(errors, isEmpty);
      expect(states, [GeminiLiveState.connecting]);
      expect(transport.connectCalls, 1);
      expect(_setupModel(transport.sent.single), 'gemini-live');

      transport.emitMessage('{"setupComplete":{}}');
      await Future<void>.delayed(Duration.zero);

      expect(states, [GeminiLiveState.connecting, GeminiLiveState.connected]);
      expect(audioAdapter.prepareCalls, 1);
      expect(audioAdapter.startCalls, 0);
      expect(_greetingText(transport.sent[1]), 'カスタム挨拶');

      transport.emitMessage(jsonEncode({
        'serverContent': {
          'inputTranscription': {'text': 'もしもし'},
          'outputTranscription': {'text': 'やっほー'},
          'modelTurn': {
            'parts': [
              {
                'inlineData': {'data': 'audio-1'},
              },
            ],
          },
          'turnComplete': true,
        },
      }));
      await Future<void>.delayed(Duration.zero);

      expect(aiTexts, ['やっほー']);
      expect(transcriptEntries, ['user:もしもし', 'assistant:やっほー']);
      expect(audioAdapter.playedAudio, ['audio-1']);
      expect(audioAdapter.startCalls, 1);

      await session.lifecycleRunner.end();

      expect(audioAdapter.stopCalls, 1);
      expect(transport.closeCalls, 1);
      expect(states, [
        GeminiLiveState.connecting,
        GeminiLiveState.connected,
        GeminiLiveState.ending,
        GeminiLiveState.ended,
      ]);
    });

    test('returns the injected lifecycle controller for service state access',
        () {
      final session = const GeminiLiveServiceSessionFactory().build(
        wsUri: 'wss://example.test/live',
        token: 'token',
        model: 'gemini-live',
        userNickname: 'Tester',
        silenceDurationMs: 900,
        jlptLevel: 'N3',
        audioAdapter: _FakeGeminiLiveAudioAdapter(),
        transport: _FakeGeminiLiveTransport(),
        emitState: _ignoreState,
        emitAiTextDelta: _ignoreText,
        emitTranscriptEntry: _ignoreTranscriptEntry,
        emitError: _ignoreText,
      );

      session.lifecycleController.isMuted = true;

      expect(session.lifecycleController.isMuted, isTrue);
    });
  });
}

String _setupModel(String payload) {
  final decoded = jsonDecode(payload) as Map<String, dynamic>;
  final setup = decoded['setup'] as Map<String, dynamic>;
  return setup['model'] as String;
}

String _greetingText(String payload) {
  final decoded = jsonDecode(payload) as Map<String, dynamic>;
  final realtimeInput = decoded['realtimeInput'] as Map<String, dynamic>;
  return realtimeInput['text'] as String;
}

void _ignoreState(GeminiLiveState state) {}

void _ignoreText(String text) {}

void _ignoreTranscriptEntry(dynamic entry) {}

class _FakeGeminiLiveTransport implements GeminiLiveTransport {
  int connectCalls = 0;
  int closeCalls = 0;
  Uri? lastUri;
  final sent = <String>[];
  void Function(dynamic raw)? _onMessage;
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
    _connected = true;
  }

  @override
  void send(String data) {
    sent.add(data);
  }

  void emitMessage(dynamic raw) {
    _onMessage?.call(raw);
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
