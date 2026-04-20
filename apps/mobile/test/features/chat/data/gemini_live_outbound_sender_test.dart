import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_outbound_sender.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_transport.dart';

void main() {
  group('GeminiLiveOutboundSender', () {
    test('sends setup payload through transport', () {
      final transport = _FakeGeminiLiveTransport();
      final sender = GeminiLiveOutboundSender(transport: transport);

      sender.sendSetup(
        model: 'gemini-live',
        voiceName: 'Kore',
        instruction: '話してください',
        userNickname: 'Tester',
        jlptSection: 'N5 only',
        silenceDurationMs: 900,
        resumptionHandle: 'resume-1',
      );

      final payload = jsonDecode(transport.sent.single) as Map<String, dynamic>;
      final setup = payload['setup'] as Map<String, dynamic>;
      final systemInstruction =
          setup['systemInstruction'] as Map<String, dynamic>;
      final parts = systemInstruction['parts'] as List<dynamic>;

      expect(setup['model'], 'gemini-live');
      expect(setup['sessionResumption'], {'handle': 'resume-1'});
      expect(parts.first, {
        'text': '話してください\n\n## ユーザー情報\n- 名前: Tester\n\nN5 only',
      });
    });

    test('sends greeting and realtime audio payloads', () {
      final transport = _FakeGeminiLiveTransport();
      final sender = GeminiLiveOutboundSender(transport: transport);

      sender.sendGreeting(
        characterName: 'ハル',
        scenarioGreeting: 'カスタム挨拶',
      );
      sender.sendRealtimeAudio(Uint8List.fromList([1, 2, 3, 4]));

      final greeting = jsonDecode(transport.sent[0]) as Map<String, dynamic>;
      final audio = jsonDecode(transport.sent[1]) as Map<String, dynamic>;
      final clientContent = greeting['clientContent'] as Map<String, dynamic>;
      final turns = clientContent['turns'] as List<dynamic>;
      final turn = turns.first as Map<String, dynamic>;
      final parts = turn['parts'] as List<dynamic>;
      final realtimeInput = audio['realtimeInput'] as Map<String, dynamic>;
      final mediaChunks = realtimeInput['mediaChunks'] as List<dynamic>;
      final chunk = mediaChunks.first as Map<String, dynamic>;

      expect(parts.first, {'text': 'カスタム挨拶'});
      expect(chunk['mimeType'], 'audio/pcm;rate=16000');
      expect(chunk['data'], base64Encode([1, 2, 3, 4]));
    });

    test('does not throw when transport send fails', () {
      final sender = GeminiLiveOutboundSender(
        transport: _FakeGeminiLiveTransport(sendError: StateError('closed')),
      );

      expect(
        () => sender.sendGreeting(
          characterName: 'ハル',
          scenarioGreeting: 'カスタム挨拶',
        ),
        returnsNormally,
      );
    });
  });
}

class _FakeGeminiLiveTransport implements GeminiLiveTransport {
  _FakeGeminiLiveTransport({this.sendError});

  final Object? sendError;
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
    final error = sendError;
    if (error != null) {
      throw error;
    }
    sent.add(data);
  }

  @override
  Future<void> close() async {}
}
