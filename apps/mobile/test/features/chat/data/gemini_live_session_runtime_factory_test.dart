import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_audio_adapter.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_audio_session.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_events.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_greeting_sender.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_lifecycle_controller.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_message_handler.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_outbound_sender.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_prompt_builder.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_reconnect_coordinator.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_session_runtime_factory.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_setup_sender.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_transport.dart';

void main() {
  group('GeminiLiveSessionRuntimeFactory', () {
    test('connects, sends setup, and handles setup complete', () async {
      final transport = _FakeGeminiLiveTransport();
      final audioAdapter = _FakeGeminiLiveAudioAdapter();
      final lifecycle = GeminiLiveLifecycleController()..markStarted();
      final states = <GeminiLiveState>[];
      final runtime = _buildRuntime(
        transport: transport,
        audioAdapter: audioAdapter,
        lifecycleController: lifecycle,
        states: states,
      );

      await runtime.connect();

      expect(transport.connectCalls, 1);
      expect(
        transport.lastUri.toString(),
        'wss://example.test/live?access_token=token',
      );
      expect(transport.sent, hasLength(1));
      expect(_setupResumptionHandle(transport.sent.single), isNull);

      transport.emitMessage('{"setupComplete":{}}');
      await Future<void>.delayed(Duration.zero);

      expect(states, [GeminiLiveState.connected]);
      expect(audioAdapter.startCalls, 1);
      expect(transport.sent, hasLength(2));
      expect(_greetingText(transport.sent.last), 'カスタム挨拶');
    });

    test('dispatches inbound text transcript and audio callbacks', () async {
      final aiTexts = <String>[];
      final transcriptEvents = <String>[];
      final audioChunks = <String>[];
      final runtime = _buildRuntime(
        aiTexts: aiTexts,
        transcriptEvents: transcriptEvents,
        audioChunks: audioChunks,
      );

      runtime.dispatch(jsonEncode({
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

      expect(aiTexts, ['やっほー']);
      expect(transcriptEvents, ['user:もしもし', 'assistant:やっほー']);
      expect(audioChunks, ['audio-1']);
    });

    test('uses the stored resumption handle on later connects', () async {
      final transport = _FakeGeminiLiveTransport();
      final runtime = _buildRuntime(transport: transport);

      runtime.dispatch('{"sessionResumptionUpdate":{"newHandle":"resume-1"}}');
      await runtime.connect();

      expect(_setupResumptionHandle(transport.sent.single), 'resume-1');
    });
  });
}

GeminiLiveSessionRuntime _buildRuntime({
  _FakeGeminiLiveTransport? transport,
  _FakeGeminiLiveAudioAdapter? audioAdapter,
  GeminiLiveLifecycleController? lifecycleController,
  List<GeminiLiveState>? states,
  List<String>? errors,
  List<String>? aiTexts,
  List<String>? transcriptEvents,
  List<String>? audioChunks,
}) {
  final liveTransport = transport ?? _FakeGeminiLiveTransport();
  final liveAudioAdapter = audioAdapter ?? _FakeGeminiLiveAudioAdapter();
  final lifecycle =
      lifecycleController ?? (GeminiLiveLifecycleController()..markStarted());
  final outboundSender = GeminiLiveOutboundSender(transport: liveTransport);
  final audioSession = GeminiLiveAudioSession(
    audioAdapter: liveAudioAdapter,
    outboundSender: outboundSender,
    isActive: () => lifecycle.isActive,
    isTransportConnected: () => liveTransport.isConnected,
    isMuted: () => lifecycle.isMuted,
    onError: (message) => errors?.add(message),
    onUnavailable: () => states?.add(GeminiLiveState.error),
  );

  return const GeminiLiveSessionRuntimeFactory().build(
    wsUri: 'wss://example.test/live',
    token: 'token',
    model: 'gemini-live',
    transport: liveTransport,
    reconnectCoordinator: GeminiLiveReconnectCoordinator(),
    lifecycleController: lifecycle,
    setupSender: GeminiLiveSetupSender(
      outboundSender: outboundSender,
      promptBuilder: const GeminiLivePromptBuilder(jlptLevel: 'N5'),
      model: 'gemini-live',
      userNickname: 'Tester',
      silenceDurationMs: 1200,
    ),
    greetingSender: GeminiLiveGreetingSender(
      outboundSender: outboundSender,
      scenarioGreeting: 'カスタム挨拶',
    ),
    audioSession: audioSession,
    messageHandler: GeminiLiveMessageHandler(),
    emitState: (state) => states?.add(state),
    emitError: (message) => errors?.add(message),
    onAiTextDelta: (text) => aiTexts?.add(text),
    onTranscriptEntry: (entry) {
      transcriptEvents?.add('${entry.role}:${entry.text}');
    },
    onAudioChunk: (base64Data) => audioChunks?.add(base64Data),
  );
}

String? _setupResumptionHandle(String payload) {
  final decoded = jsonDecode(payload) as Map<String, dynamic>;
  final setup = decoded['setup'] as Map<String, dynamic>;
  final sessionResumption = setup['sessionResumption'] as Map<String, dynamic>;
  return sessionResumption['handle'] as String?;
}

String _greetingText(String payload) {
  final decoded = jsonDecode(payload) as Map<String, dynamic>;
  final clientContent = decoded['clientContent'] as Map<String, dynamic>;
  final turns = clientContent['turns'] as List<dynamic>;
  final turn = turns.first as Map<String, dynamic>;
  final parts = turn['parts'] as List<dynamic>;
  final part = parts.first as Map<String, dynamic>;
  return part['text'] as String;
}

class _FakeGeminiLiveTransport implements GeminiLiveTransport {
  int connectCalls = 0;
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
    _connected = false;
  }
}

class _FakeGeminiLiveAudioAdapter implements GeminiLiveAudioAdapter {
  int startCalls = 0;

  @override
  Future<GeminiLiveAudioStartResult> startRecording({
    required void Function(Uint8List data) onData,
  }) async {
    startCalls++;
    return GeminiLiveAudioStartResult.started;
  }

  @override
  Future<void> stopRecording() async {}

  @override
  void playBase64Pcm(String base64Data) {}

  @override
  Future<void> dispose() async {}
}
