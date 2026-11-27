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

  testWidgets('LessonVocabLearningStep shows Korean part-of-speech labels',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonVocabLearningStep(
            vocabItems: const [
              VocabItemModel(
                id: 'vocab-1',
                word: 'はじめまして',
                reading: 'はじめまして',
                meaningKo: '처음 뵙겠습니다',
                partOfSpeech: 'EXPRESSION',
              ),
            ],
            onNext: () {},
          ),
        ),
      ),
    );

    expect(find.text('표현'), findsOneWidget);
    expect(find.text('EXPRESSION'), findsNothing);
  });

  testWidgets('LessonVocabLearningStep normalizes lowercase part-of-speech',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonVocabLearningStep(
            vocabItems: const [
              VocabItemModel(
                id: 'vocab-1',
                word: '私',
                reading: 'わたし',
                meaningKo: '저',
                partOfSpeech: 'pronoun',
              ),
            ],
            onNext: () {},
          ),
        ),
      ),
    );

    expect(find.text('대명사'), findsOneWidget);
    expect(find.text('pronoun'), findsNothing);
  });

  testWidgets('separates item navigation from stage navigation',
      (tester) async {
    final selected = <int>[];
    var previousStage = 0;
    var nextStage = 0;
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
              VocabItemModel(
                id: 'vocab-2',
                word: '静か',
                reading: 'しずか',
                meaningKo: '조용함',
                partOfSpeech: 'NA_ADJECTIVE',
              ),
            ],
            onBackToPrev: () => previousStage++,
            onNext: () => nextStage++,
            onIndexChanged: selected.add,
          ),
        ),
      ),
    );

    final previousItem = find.widgetWithText(OutlinedButton, '이전 단어');
    final nextItem = find.widgetWithText(OutlinedButton, '다음 단어');
    final advance = find.widgetWithText(FilledButton, '다음학습');

    final count = find.text('단어 1 / 2');
    expect(count, findsOneWidget);
    expect(tester.getTopRight(count).dx,
        tester.getTopRight(find.byType(Scaffold)).dx - 40);
    expect(tester.widget<OutlinedButton>(previousItem).onPressed, isNull);
    expect(tester.widget<FilledButton>(advance).onPressed, isNull);
    final advanceSurface =
        find.descendant(of: advance, matching: find.byType(Material));
    expect(tester.getSize(advanceSurface).height, 42);
    expect(tester.getSize(advance).height, 48);

    await tester.tap(nextItem);
    await tester.pumpAndSettle();
    expect(find.text('단어 2 / 2'), findsOneWidget);
    expect(find.text('나형용사'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(nextItem).onPressed, isNull);
    expect(tester.widget<FilledButton>(advance).onPressed, isNotNull);

    await tester.tap(previousItem);
    await tester.pumpAndSettle();
    expect(selected, [1, 0]);
    expect(previousStage, 0);
    expect(nextStage, 0);

    await tester.tap(find.widgetWithText(OutlinedButton, '이전'));
    await tester.pump();
    expect(previousStage, 1);

    await tester.tap(nextItem);
    await tester.pumpAndSettle();
    await tester.tap(advance);
    await tester.pump();
    expect(nextStage, 1);
  });
}
