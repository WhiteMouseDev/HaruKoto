import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_dialogue_bubble.dart';
import 'package:harukoto_mobile/shared/widgets/tts_play_button.dart';

void main() {
  testWidgets('LessonDialogueBubble hides kana TTS for kanji dialogue text',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LessonDialogueBubble(
            line: ScriptLineModel(
              speaker: 'A',
              voiceId: 'voice-a',
              text: '学生です',
            ),
          ),
        ),
      ),
    );

    expect(find.byType(TtsPlayButton), findsNothing);
  });

  testWidgets('LessonDialogueBubble shows kana TTS for kana-only short text',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LessonDialogueBubble(
            line: ScriptLineModel(
              speaker: 'A',
              voiceId: 'voice-a',
              text: 'はい',
            ),
          ),
        ),
      ),
    );

    final button = tester.widget<TtsPlayButton>(find.byType(TtsPlayButton));
    expect(button.text, 'はい');
    expect(button.vocabId, isNull);
  });
}
