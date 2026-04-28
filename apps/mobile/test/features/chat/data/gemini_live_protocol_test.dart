import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_protocol.dart';

void main() {
  group('GeminiLiveProtocol', () {
    test('encodeSetup builds the expected setup payload', () {
      final encoded = GeminiLiveProtocol.encodeSetup(
        const GeminiLiveSetupConfig(
          model: 'gemini-live',
          voiceName: 'Kore',
          instruction: '話してください',
          userNickname: 'Tester',
          jlptSection: 'N5 only',
          silenceDurationMs: 1200,
          resumptionHandle: 'resume-1',
        ),
      );

      final payload = jsonDecode(encoded) as Map<String, dynamic>;
      final setup = payload['setup'] as Map<String, dynamic>;
      final generationConfig =
          setup['generationConfig'] as Map<String, dynamic>;
      final realtimeConfig =
          setup['realtimeInputConfig'] as Map<String, dynamic>;
      final activityDetection =
          realtimeConfig['automaticActivityDetection'] as Map<String, dynamic>;
      final systemInstruction =
          setup['systemInstruction'] as Map<String, dynamic>;
      final parts = systemInstruction['parts'] as List<dynamic>;

      expect(setup['model'], 'gemini-live');
      expect(generationConfig['responseModalities'], ['AUDIO']);
      expect(
        activityDetection['startOfSpeechSensitivity'],
        'START_SENSITIVITY_HIGH',
      );
      expect(
        activityDetection['endOfSpeechSensitivity'],
        'END_SENSITIVITY_HIGH',
      );
      expect(
        activityDetection.values,
        isNot(contains('START_SENSITIVITY_MEDIUM')),
      );
      expect(
        activityDetection.values,
        isNot(contains('END_SENSITIVITY_MEDIUM')),
      );
      expect(activityDetection['silenceDurationMs'], 1200);
      expect(realtimeConfig['activityHandling'], 'NO_INTERRUPTION');
      expect(setup['sessionResumption'], {'handle': 'resume-1'});
      expect(parts.first, {
        'text':
            '話してください\n\n## ユーザー情報\n- 名前: Tester\n- 相手を呼ぶ時は「学習者」ではなく、この名前を関係設定の呼び方ルールに合わせて呼ぶこと。\n\nN5 only',
      });
    });

    test('encodeGreeting uses the scenario greeting when provided', () {
      final encoded = GeminiLiveProtocol.encodeGreeting(
        characterName: 'ハル',
        scenarioGreeting: 'カスタム挨拶',
      );

      final payload = jsonDecode(encoded) as Map<String, dynamic>;
      final realtimeInput = payload['realtimeInput'] as Map<String, dynamic>;

      expect(realtimeInput['text'], 'カスタム挨拶');
    });

    test('encodeRealtimeAudio base64 encodes PCM bytes', () {
      final encoded = GeminiLiveProtocol.encodeRealtimeAudio(
        Uint8List.fromList([1, 2, 3, 4]),
      );

      final payload = jsonDecode(encoded) as Map<String, dynamic>;
      final realtimeInput = payload['realtimeInput'] as Map<String, dynamic>;
      final chunk = realtimeInput['audio'] as Map<String, dynamic>;

      expect(chunk['mimeType'], 'audio/pcm;rate=16000');
      expect(chunk['data'], base64Encode([1, 2, 3, 4]));
    });

    test('parseMessage accepts string and binary websocket frames', () {
      const text = '{"setupComplete":{}}';

      expect(
        GeminiLiveProtocol.parseMessage(text),
        {'setupComplete': {}},
      );
      expect(
        GeminiLiveProtocol.parseMessage(utf8.encode(text)),
        {'setupComplete': {}},
      );
    });

    test('parseMessage returns null for unknown websocket frame types', () {
      expect(GeminiLiveProtocol.parseMessage(Object()), isNull);
    });
  });
}
