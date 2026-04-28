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
              'text':
                  '${config.instruction}\n\n## ユーザー情報\n- 名前: ${config.userNickname}\n- 相手を呼ぶ時は「学習者」ではなく、この名前を関係設定の呼び方ルールに合わせて呼ぶこと。\n\n${config.jlptSection}'
            },
          ],
        },
        'realtimeInputConfig': {
          'activityHandling': 'NO_INTERRUPTION',
          'automaticActivityDetection': {
            'startOfSpeechSensitivity': 'START_SENSITIVITY_HIGH',
            'endOfSpeechSensitivity': 'END_SENSITIVITY_HIGH',
            'prefixPaddingMs': 200,
            'silenceDurationMs': config.silenceDurationMs,
          },
        },
        'inputAudioTranscription': {},
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
    final greeting =
        scenarioGreeting ?? '[システム] $nameから電話がかかってきました。電話に出て「もしもし」から始めてください。';

    return jsonEncode({
      'realtimeInput': {
        'text': greeting,
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
