import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_audio_adapter.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_lifecycle_controller.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_outbound_sender.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_prompt_builder.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_session_components_factory.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_transport.dart';

void main() {
  group('GeminiLiveSessionComponentsFactory', () {
    test('builds setup greeting and audio session from shared dependencies',
        () async {
      final transport = _FakeGeminiLiveTransport();
      final audioAdapter = _FakeGeminiLiveAudioAdapter();
      final lifecycle = GeminiLiveLifecycleController();
      final components = _buildComponents(
        transport: transport,
        audioAdapter: audioAdapter,
        lifecycleController: lifecycle,
      );

      components.setupSender.send(resumptionHandle: 'resume-1');
      components.greetingSender.send();
      await components.audioSession.startRecording();
      audioAdapter.emitRecordedAudio(Uint8List.fromList([1, 2, 3]));
      lifecycle.isMuted = true;
      audioAdapter.emitRecordedAudio(Uint8List.fromList([4]));

      expect(audioAdapter.startCalls, 1);
      expect(transport.sent, hasLength(3));

      final setup = _decode(transport.sent[0])['setup'] as Map<String, dynamic>;
      final systemInstruction =
          setup['systemInstruction'] as Map<String, dynamic>;
      final parts = systemInstruction['parts'] as List<dynamic>;
      final instruction = parts.first as Map<String, dynamic>;

      expect(setup['model'], 'gemini-live');
      expect(setup['sessionResumption'], {'handle': 'resume-1'});
      expect(instruction['text'], contains('Tester'));
      expect(instruction['text'], contains('JLPT N3'));

      final greeting =
          _decode(transport.sent[1])['clientContent'] as Map<String, dynamic>;
      final turns = greeting['turns'] as List<dynamic>;
      final turn = turns.single as Map<String, dynamic>;
      final greetingParts = turn['parts'] as List<dynamic>;
      expect(greetingParts.single, {'text': 'カスタム挨拶'});

      final audio =
          _decode(transport.sent[2])['realtimeInput'] as Map<String, dynamic>;
      final chunks = audio['mediaChunks'] as List<dynamic>;
      final chunk = chunks.single as Map<String, dynamic>;
      expect(chunk['mimeType'], 'audio/pcm;rate=16000');
      expect(chunk['data'], base64Encode([1, 2, 3]));
    });

    test('wires audio adapter failures to error and unavailable callbacks',
        () async {
      final errors = <String>[];
      var unavailableCalls = 0;
      final components = _buildComponents(
        audioAdapter: _FakeGeminiLiveAudioAdapter(
          result: GeminiLiveAudioStartResult.unavailable,
        ),
        errors: errors,
        onUnavailable: () => unavailableCalls++,
      );

      await components.audioSession.startRecording();

      expect(errors, ['마이크를 사용할 수 없습니다. 기기를 확인해주세요.']);
      expect(unavailableCalls, 1);
    });
  });
}

GeminiLiveSessionComponents _buildComponents({
  _FakeGeminiLiveTransport? transport,
  _FakeGeminiLiveAudioAdapter? audioAdapter,
  GeminiLiveLifecycleController? lifecycleController,
  List<String>? errors,
  void Function()? onUnavailable,
}) {
  final liveTransport = transport ?? _FakeGeminiLiveTransport();
  return const GeminiLiveSessionComponentsFactory().build(
    model: 'gemini-live',
    userNickname: 'Tester',
    silenceDurationMs: 900,
    audioAdapter: audioAdapter ?? _FakeGeminiLiveAudioAdapter(),
    outboundSender: GeminiLiveOutboundSender(transport: liveTransport),
    promptBuilder: const GeminiLivePromptBuilder(jlptLevel: 'N3'),
    lifecycleController: lifecycleController ?? GeminiLiveLifecycleController(),
    transport: liveTransport,
    emitError: errors?.add ?? _ignoreError,
    emitAudioUnavailable: onUnavailable ?? _ignoreUnavailable,
    voiceName: 'Kore',
    characterName: 'ハル',
    scenarioGreeting: 'カスタム挨拶',
  );
}

Map<String, dynamic> _decode(String data) {
  return jsonDecode(data) as Map<String, dynamic>;
}

void _ignoreError(String message) {}

void _ignoreUnavailable() {}

class _FakeGeminiLiveAudioAdapter implements GeminiLiveAudioAdapter {
  _FakeGeminiLiveAudioAdapter({
    this.result = GeminiLiveAudioStartResult.started,
  });

  final GeminiLiveAudioStartResult result;
  int startCalls = 0;
  void Function(Uint8List data)? _onData;

  @override
  Future<GeminiLiveAudioStartResult> startRecording({
    required void Function(Uint8List data) onData,
  }) async {
    startCalls++;
    _onData = onData;
    return result;
  }

  void emitRecordedAudio(Uint8List data) {
    _onData?.call(data);
  }

  @override
  Future<void> stopRecording() async {}

  @override
  void playBase64Pcm(String base64Data) {}

  @override
  Future<void> dispose() async {}
}

class _FakeGeminiLiveTransport implements GeminiLiveTransport {
  final sent = <String>[];

  @override
  bool get isConnected => true;

  @override
  Future<void> connect(
    Uri uri, {
    required void Function(dynamic raw) onMessage,
    required void Function(Object error) onError,
    required void Function() onDone,
  }) async {}

  @override
  void send(String data) {
    sent.add(data);
  }

  @override
  Future<void> close() async {}
}
