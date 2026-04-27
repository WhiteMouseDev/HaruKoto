import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_greeting_sender.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_outbound_sender.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_transport.dart';

void main() {
  group('GeminiLiveGreetingSender', () {
    test('sends configured greeting through outbound sender', () {
      final transport = _FakeGeminiLiveTransport();
      final sender = GeminiLiveGreetingSender(
        outboundSender: GeminiLiveOutboundSender(transport: transport),
        characterName: 'ハル',
        scenarioGreeting: 'カスタム挨拶',
      );

      sender.send();

      final payload = jsonDecode(transport.sent.single) as Map<String, dynamic>;
      final realtimeInput = payload['realtimeInput'] as Map<String, dynamic>;

      expect(realtimeInput['text'], 'カスタム挨拶');
    });
  });
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
