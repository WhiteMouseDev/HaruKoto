import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_vocab_learning_step.dart';
import 'package:harukoto_mobile/shared/widgets/tts_play_button.dart';

void main() {
  testWidgets('LessonVocabLearningStep uses vocabulary id for TTS',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonVocabLearningStep(
            vocabItems: const [
              VocabItemModel(
                id: 'vocab-1',
                word: '学生',
                reading: 'がくせい',
                meaningKo: '학생',
                partOfSpeech: 'NOUN',
              ),
            ],
            onNext: () {},
          ),
        ),
      ),
    );

    final button = tester.widget<TtsPlayButton>(find.byType(TtsPlayButton));
    expect(button.vocabId, 'vocab-1');
    expect(button.text, isNull);
  });

  testWidgets(
      'LessonVocabLearningStep falls back to reading when id is missing',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonVocabLearningStep(
            vocabItems: const [
              VocabItemModel(
                id: '',
                word: '学生',
                reading: 'がくせい',
                meaningKo: '학생',
                partOfSpeech: 'NOUN',
              ),
            ],
            onNext: () {},
          ),
        ),
      ),
    );

    final button = tester.widget<TtsPlayButton>(find.byType(TtsPlayButton));
    expect(button.vocabId, isNull);
    expect(button.text, 'がくせい');
  });
}
