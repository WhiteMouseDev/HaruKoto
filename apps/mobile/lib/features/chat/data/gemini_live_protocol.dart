import 'dart:convert';
import 'dart:typed_data';

class GeminiLiveSetupConfig {
  const GeminiLiveSetupConfig({
    required this.model,
    required this.instruction,
    required this.userNickname,
    required this.jlptSection,
    required this.silenceDurationMs,
    this.voiceName,
    this.resumptionHandle,
  });

  final String model;
  final String instruction;
  final String userNickname;
  final String jlptSection;
  final int silenceDurationMs;
  final String? voiceName;
  final String? resumptionHandle;
}

class GeminiLiveProtocol {
  const GeminiLiveProtocol._();

  static String encodeSetup(GeminiLiveSetupConfig config) {
    return jsonEncode({
      'setup': {
        'model': config.model,
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {
                'voiceName': config.voiceName ?? 'Kore',
              },
            },
          },
        },
        'systemInstruction': {
          'parts': [
            {
              'text': '${config.instruction}\n\n## 共通ルール（設定が矛盾する場合はこちらを優先）\n'
                  '- 通常の会話は日本語。学習者が明示的に意味や返答ヒントを求めた時だけ、短い韓国語の説明を行う。\n'
                  '- この学習サポートはキャラクターの「日本語のみ」「韓国語で説明しない」という制限より優先する。説明後は返答を待ち、通常の会話では日本語に戻る。\n'
                  '- JLPTレベルは語彙・文法・文の長さの難易度を定める。敬体・普通体は関係設定と場面に合う口調を優先する。初対面の接客では丁寧に、親しい友人とは親しい口調で、どちらも学習者にわかる短い文を使う。\n\n'
                  '## ユーザー情報\n'
                  '- アプリのニックネーム: ${config.userNickname}\n'
                  '- 友人など、すでに相手の名前を知っている関係の場合に限り、このニックネームを関係設定の呼び方に合わせて使う。\n'
                  '- このニックネームをシナリオ内の実名・予約名・注文名として扱わない。初対面の店員などは、相手が会話で名乗るまで名前で呼ばない。\n'
                  '- 会話で明示された名前を優先する。\n\n${config.jlptSection}'
            },
          ],
        },
        'realtimeInputConfig': {
          'activityHandling': 'NO_INTERRUPTION',
          'automaticActivityDetection': {
            // Let the server choose start sensitivity: explicit HIGH can turn
            // background noise into phantom speech on Gemini 3.8 Live.
            'endOfSpeechSensitivity': 'END_SENSITIVITY_HIGH',
            'prefixPaddingMs': 200,
            'silenceDurationMs': config.silenceDurationMs,
          },
        },
        'inputAudioTranscription': {
          'languageCodes': ['ja-JP', 'ko-KR'],
        },
        'outputAudioTranscription': {},
        'sessionResumption': config.resumptionHandle != null
            ? {'handle': config.resumptionHandle}
            : {},
      },
    });
  }

  static String encodeGreeting({
    required String? characterName,
    required String? scenarioGreeting,
  }) {
    final name = characterName ?? 'ハル';
    final greeting = scenarioGreeting ??
        '[システム] ユーザーが$nameに電話をかけました。あなたは電話を受けて「もしもし」から始めてください。';

    return encodeRealtimeText(greeting);
  }

  static String encodeRealtimeText(String text) {
    return jsonEncode({
      'realtimeInput': {
        'text': text,
      },
    });
  }

  static String encodeRealtimeAudio(Uint8List data) {
    return jsonEncode({
      'realtimeInput': {
        'audio': {
          'mimeType': 'audio/pcm;rate=16000',
          'data': base64Encode(data),
        },
      },
    });
  }

  static Map<String, dynamic>? parseMessage(dynamic raw) {
    final String text;
    if (raw is String) {
      text = raw;
    } else if (raw is List<int>) {
      text = utf8.decode(raw);
    } else {
      return null;
    }

    final decoded = jsonDecode(text);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const FormatException('Gemini Live message must be a JSON object');
  }
}
