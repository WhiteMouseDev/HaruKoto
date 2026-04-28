import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_audio_adapter.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_lifecycle_controller.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_message_handler.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_prompt_builder.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_reconnect_coordinator.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_session_dependencies.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_transport.dart';

void main() {
  group('GeminiLiveSessionDependenciesFactory', () {
    test(
        'preserves injected dependencies and wires outbound sender to transport',
        () {
      final audioAdapter = _FakeGeminiLiveAudioAdapter();
      final messageHandler = GeminiLiveMessageHandler();
      const promptBuilder = GeminiLivePromptBuilder(jlptLevel: 'N3');
      final reconnectCoordinator = GeminiLiveReconnectCoordinator();
      final lifecycleController = GeminiLiveLifecycleController();
      final transport = _FakeGeminiLiveTransport();

      final dependencies = const GeminiLiveSessionDependenciesFactory().build(
        jlptLevel: 'N5',
        audioAdapter: audioAdapter,
        messageHandler: messageHandler,
        promptBuilder: promptBuilder,
        reconnectCoordinator: reconnectCoordinator,
        lifecycleController: lifecycleController,
        transport: transport,
      );

      expect(identical(dependencies.audioAdapter, audioAdapter), isTrue);
      expect(identical(dependencies.messageHandler, messageHandler), isTrue);
      expect(identical(dependencies.promptBuilder, promptBuilder), isTrue);
      expect(
        identical(dependencies.reconnectCoordinator, reconnectCoordinator),
        isTrue,
      );
      expect(
        identical(dependencies.lifecycleController, lifecycleController),
        isTrue,
      );
      expect(identical(dependencies.transport, transport), isTrue);

      dependencies.outboundSender.sendRealtimeAudio(Uint8List.fromList([1]));

      expect(transport.sent, hasLength(1));
    });

    test('builds default prompt builder from session context', () {
      final dependencies = const GeminiLiveSessionDependenciesFactory().build(
        jlptLevel: 'N2',
        systemInstruction: 'custom instruction',
        audioAdapter: _FakeGeminiLiveAudioAdapter(),
        transport: _FakeGeminiLiveTransport(),
      );

      expect(dependencies.promptBuilder.jlptLevel, 'N2');
      expect(
          dependencies.promptBuilder.systemInstruction, 'custom instruction');
    });
  });
}

class _FakeGeminiLiveAudioAdapter implements GeminiLiveAudioAdapter {
  @override
  Future<GeminiLiveAudioPlaybackPrepareResult> preparePlayback() async {
    return GeminiLiveAudioPlaybackPrepareResult.ready;
  }

  @override
  Future<GeminiLiveAudioStartResult> startRecording({
    required void Function(Uint8List data) onData,
  }) async {
    return GeminiLiveAudioStartResult.started;
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
