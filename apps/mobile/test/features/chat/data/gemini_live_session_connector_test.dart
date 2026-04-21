import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_connection_runner.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_outbound_sender.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_prompt_builder.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_reconnect_coordinator.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_session_connector.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_setup_sender.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_transport.dart';

void main() {
  group('GeminiLiveSessionConnector', () {
    test('connects transport then sends setup with resumption handle',
        () async {
      final events = <String>[];
      final transport = _RecordingGeminiLiveTransport(events);
      final reconnectCoordinator = GeminiLiveReconnectCoordinator()
        ..updateResumptionHandle('resume-existing');
      final connector = GeminiLiveSessionConnector(
        connectionRunner: GeminiLiveConnectionRunner(
          transport: transport,
          reconnectCoordinator: reconnectCoordinator,
          isActive: () => true,
          onMessage: (_) {},
          onReconnect: () {},
        ),
        reconnectCoordinator: reconnectCoordinator,
        setupSender: GeminiLiveSetupSender(
          outboundSender: GeminiLiveOutboundSender(transport: transport),
          promptBuilder: const GeminiLivePromptBuilder(jlptLevel: 'N5'),
          model: 'gemini-live',
          userNickname: 'Tester',
          silenceDurationMs: 1200,
        ),
      );

      await connector.connect(
        const GeminiLiveConnectionInput(
          wsUri: 'wss://example.test/live',
          token: 'token',
          model: 'gemini-live',
        ),
      );

      expect(events, ['connect', 'send']);
      expect(
        transport.lastUri.toString(),
        'wss://example.test/live?access_token=token',
      );
      expect(
          _sessionResumptionHandle(transport.sent.single), 'resume-existing');

      await connector.connect(
        const GeminiLiveConnectionInput(
          wsUri: 'wss://example.test/live',
          token: 'token',
          model: 'gemini-live',
        ),
        resumptionHandle: 'resume-explicit',
      );

      expect(events, ['connect', 'send', 'connect', 'send']);
      expect(_sessionResumptionHandle(transport.sent.last), 'resume-explicit');
    });
  });
}

String? _sessionResumptionHandle(String payload) {
  final decoded = jsonDecode(payload) as Map<String, dynamic>;
  final setup = decoded['setup'] as Map<String, dynamic>;
  final sessionResumption = setup['sessionResumption'] as Map<String, dynamic>;
  return sessionResumption['handle'] as String?;
}

class _RecordingGeminiLiveTransport implements GeminiLiveTransport {
  _RecordingGeminiLiveTransport(this.events);

  final List<String> events;
  final sent = <String>[];
  Uri? lastUri;

  @override
  bool get isConnected => true;

  @override
  Future<void> connect(
    Uri uri, {
    required void Function(dynamic raw) onMessage,
    required void Function(Object error) onError,
    required void Function() onDone,
  }) async {
    lastUri = uri;
    events.add('connect');
  }

  @override
  void send(String data) {
    sent.add(data);
    events.add('send');
  }

  @override
  Future<void> close() async {}
}
