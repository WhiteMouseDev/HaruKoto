import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_prompt_builder.dart';
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
        activityDetection.containsKey('startOfSpeechSensitivity'),
        isFalse,
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
      expect(activityDetection['prefixPaddingMs'], 200);
      expect(realtimeConfig['activityHandling'], 'NO_INTERRUPTION');
      expect(setup['inputAudioTranscription'], {
        'languageCodes': ['ja-JP', 'ko-KR'],
      });
      expect(setup['outputAudioTranscription'], isEmpty);
      expect(setup['sessionResumption'], {'handle': 'resume-1'});
      final instruction =
          (parts.first as Map<String, dynamic>)['text'] as String;
      expect(instruction, startsWith('話してください'));
      expect(instruction, contains('アプリのニックネーム: Tester'));
      expect(instruction, contains('すでに相手の名前を知っている関係の場合に限り'));
      expect(instruction, endsWith('N5 only'));
    });

    test(
        'hotel setup does not assign the profile nickname as a reservation name',
        () {
      final payload = jsonDecode(GeminiLiveProtocol.encodeSetup(
        const GeminiLiveSetupConfig(
          model: 'gemini-live',
          instruction: 'あなたは初対面のホテルの受付スタッフです。予約名を質問してください。',
          userNickname: 'ユイ',
          jlptSection: 'N5 only',
          silenceDurationMs: 1200,
        ),
      )) as Map<String, dynamic>;
      final setup = payload['setup'] as Map<String, dynamic>;
      final system = setup['systemInstruction'] as Map<String, dynamic>;
      final parts = system['parts'] as List<dynamic>;
      final instruction =
          (parts.single as Map<String, dynamic>)['text'] as String;

      expect(instruction, contains('予約名を質問してください'));
      expect(instruction, contains('アプリのニックネーム: ユイ'));
      expect(instruction, isNot(contains('- 名前: ユイ')));
      expect(instruction, contains('実名・予約名・注文名として扱わない'));
      expect(instruction, contains('相手が会話で名乗るまで名前で呼ばない'));
      expect(instruction, contains('会話で明示された名前を優先する'));
      expect(instruction, isNot(contains('この名前を関係設定の呼び方ルールに合わせて呼ぶこと')));
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

    test(
        'explicit support overrides persona language limits without changing its relationship',
        () {
      const persona = 'ユーザーとは幼なじみ。敬語は使わない。韓国語で説明しない（日本語のみ）。';
      const prompt =
          GeminiLivePromptBuilder(jlptLevel: 'N5', systemInstruction: persona);
      final payload = jsonDecode(GeminiLiveProtocol.encodeSetup(
        GeminiLiveSetupConfig(
          model: 'gemini-live',
          instruction: prompt.instruction,
          userNickname: 'ユイ',
          jlptSection: prompt.jlptSection,
          silenceDurationMs: 1200,
        ),
      )) as Map<String, dynamic>;
      final setup = payload['setup'] as Map<String, dynamic>;
      final system = setup['systemInstruction'] as Map<String, dynamic>;
      final parts = system['parts'] as List<dynamic>;
      final instruction =
          (parts.single as Map<String, dynamic>)['text'] as String;

      expect(instruction, startsWith(persona));
      expect(instruction, contains('通常の会話は日本語'));
      expect(instruction, contains('明示的に意味や返答ヒントを求めた時だけ'));
      expect(instruction, contains('キャラクターの「日本語のみ」「韓国語で説明しない」という制限より優先'));
      expect(instruction, contains('関係設定と場面に合う口調を優先'));
      expect(instruction, contains('初対面の接客では丁寧に、親しい友人とは親しい口調'));
      expect(instruction, isNot(contains('です/ます形のみ使用')));
    });

    test('friend greeting treats the learner as the caller', () {
      final payload = jsonDecode(GeminiLiveProtocol.encodeGreeting(
        characterName: 'ハル',
        scenarioGreeting: null,
      )) as Map<String, dynamic>;
      final input = payload['realtimeInput'] as Map<String, dynamic>;
      expect(input['text'], contains('ユーザーがハルに電話をかけました'));
      expect(input['text'], contains('あなたは電話を受けて'));
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
