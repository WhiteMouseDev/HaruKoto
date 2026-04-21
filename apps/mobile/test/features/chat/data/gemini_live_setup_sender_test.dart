import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_outbound_sender.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_prompt_builder.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_setup_sender.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_transport.dart';

void main() {
  group('GeminiLiveSetupSender', () {
    test('sends setup using prompt builder context and session settings', () {
      final transport = _FakeGeminiLiveTransport();
      final sender = GeminiLiveSetupSender(
        outboundSender: GeminiLiveOutboundSender(transport: transport),
        promptBuilder: const GeminiLivePromptBuilder(
          jlptLevel: 'N3',
          systemInstruction: '会話してください',
        ),
        model: 'gemini-live',
        voiceName: 'Kore',
        userNickname: 'Tester',
        silenceDurationMs: 900,
      );

      sender.send(resumptionHandle: 'resume-1');

      final payload = jsonDecode(transport.sent.single) as Map<String, dynamic>;
      final setup = payload['setup'] as Map<String, dynamic>;
      final generationConfig =
          setup['generationConfig'] as Map<String, dynamic>;
      final speechConfig =
          generationConfig['speechConfig'] as Map<String, dynamic>;
      final voiceConfig = speechConfig['voiceConfig'] as Map<String, dynamic>;
      final prebuiltVoiceConfig =
          voiceConfig['prebuiltVoiceConfig'] as Map<String, dynamic>;
      final systemInstruction =
          setup['systemInstruction'] as Map<String, dynamic>;
      final parts = systemInstruction['parts'] as List<dynamic>;
      final instruction = parts.first as Map<String, dynamic>;

      expect(setup['model'], 'gemini-live');
      expect(setup['sessionResumption'], {'handle': 'resume-1'});
      expect(prebuiltVoiceConfig['voiceName'], 'Kore');
      expect(instruction['text'], contains('会話してください'));
      expect(instruction['text'], contains('Tester'));
      expect(instruction['text'], contains('JLPT N3'));
      expect(
        setup['realtimeInputConfig'],
        containsPair('automaticActivityDetection', isA<Map<String, dynamic>>()),
      );
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
