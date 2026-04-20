import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_prompt_builder.dart';

void main() {
  group('GeminiLivePromptBuilder', () {
    test('uses the default system instruction when no override is provided',
        () {
      const builder = GeminiLivePromptBuilder(jlptLevel: 'N5');

      expect(
        builder.instruction,
        contains('あなたは日本に住んでいる日本人'),
      );
      expect(builder.instruction, contains('電話の会話です'));
    });

    test('uses explicit system instruction when provided', () {
      const builder = GeminiLivePromptBuilder(
        jlptLevel: 'N5',
        systemInstruction: 'カスタム指示',
      );

      expect(builder.instruction, 'カスタム指示');
    });

    test('builds JLPT level sections', () {
      expect(
        const GeminiLivePromptBuilder(jlptLevel: 'N5').jlptSection,
        contains('JLPT N5'),
      );
      expect(
        const GeminiLivePromptBuilder(jlptLevel: 'N3').jlptSection,
        contains('語彙3,000語以内'),
      );
      expect(
        const GeminiLivePromptBuilder(jlptLevel: 'N1').jlptSection,
        contains('語彙制限なし'),
      );
    });

    test('returns an empty JLPT section for unknown levels', () {
      expect(
        const GeminiLivePromptBuilder(jlptLevel: 'unknown').jlptSection,
        isEmpty,
      );
    });
  });
}
