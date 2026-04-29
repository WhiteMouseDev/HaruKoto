import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_context_preview_step.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_vocab_preview_chip.dart';

void main() {
  group('LessonContextPreviewStep', () {
    testWidgets('deduplicates repeated grammar preview cards', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonContextPreviewStep(
              detail: _detailWithGrammar([
                const GrammarItemModel(
                  id: 'grammar-1',
                  pattern: '〜です',
                  meaningKo: '~입니다 / ~이에요',
                  explanation: '정중한 단정 표현',
                ),
                const GrammarItemModel(
                  id: 'grammar-2',
                  pattern: '~ です',
                  meaningKo: '~입니다 / ~이에요',
                  explanation: '정중한 단정 표현',
                ),
                const GrammarItemModel(
                  id: 'grammar-3',
                  pattern: '～です',
                  meaningKo: '~입니다 / ~이에요',
                  explanation: '정중한 단정 표현',
                ),
                const GrammarItemModel(
                  id: 'grammar-4',
                  pattern: '〜ます',
                  meaningKo: '~합니다',
                  explanation: '정중한 동사 표현',
                ),
              ]),
              onNext: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('〜です'), findsOneWidget);
      expect(find.text('~ です'), findsNothing);
      expect(find.text('～です'), findsNothing);
      expect(find.text('〜ます'), findsOneWidget);
      expect(find.text('+0개'), findsNothing);
    });

    testWidgets('shows fixed height vocab preview and opens full list',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonContextPreviewStep(
              detail: _detailWithGrammar(
                const [],
                vocabItems: const [
                  VocabItemModel(
                    id: 'vocab-1',
                    word: 'はじめまして',
                    reading: 'はじめまして',
                    meaningKo: '처음 뵙겠습니다',
                    partOfSpeech: 'expression',
                  ),
                  VocabItemModel(
                    id: 'vocab-2',
                    word: '私',
                    reading: 'わたし',
                    meaningKo: '저',
                    partOfSpeech: 'pronoun',
                  ),
                  VocabItemModel(
                    id: 'vocab-3',
                    word: '名前',
                    reading: 'なまえ',
                    meaningKo: '이름',
                    partOfSpeech: 'noun',
                  ),
                  VocabItemModel(
                    id: 'vocab-4',
                    word: '大学',
                    reading: 'だいがく',
                    meaningKo: '대학교',
                    partOfSpeech: 'noun',
                  ),
                  VocabItemModel(
                    id: 'vocab-5',
                    word: '料理',
                    reading: 'りょうり',
                    meaningKo: '요리',
                    partOfSpeech: 'noun',
                  ),
                ],
              ),
              onNext: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('핵심 단어 미리보기'), findsOneWidget);
      expect(find.text('총 5개'), findsWidgets);
      expect(find.byType(LessonVocabPreviewChip), findsNWidgets(3));
      expect(find.byType(LessonVocabPreviewMoreChip), findsOneWidget);

      for (var index = 0; index < 3; index++) {
        expect(
          tester.getSize(find.byType(LessonVocabPreviewChip).at(index)).height,
          LessonVocabPreviewChip.height,
        );
      }

      final wordTop = tester.getTopLeft(find.text('私')).dy;
      final readingTop = tester.getTopLeft(find.text('わたし')).dy;
      final meaningTop = tester.getTopLeft(find.text('저')).dy;
      expect(wordTop, lessThan(readingTop));
      expect(readingTop, lessThan(meaningTop));

      final noReadingWordTop = tester.getTopLeft(find.text('はじめまして')).dy;
      final noReadingMeaningTop = tester.getTopLeft(find.text('처음 뵙겠습니다')).dy;
      expect(noReadingWordTop, lessThan(noReadingMeaningTop));

      await tester.tap(find.byType(LessonVocabPreviewMoreChip));
      await tester.pumpAndSettle();

      expect(find.text('배울 단어 5개'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('大学'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('大学'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('料理'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('料理'), findsOneWidget);
    });
  });
}

LessonDetailModel _detailWithGrammar(
  List<GrammarItemModel> grammarItems, {
  List<VocabItemModel> vocabItems = const [],
}) {
  return LessonDetailModel(
    id: 'lesson-1',
    lessonNo: 1,
    chapterLessonNo: 1,
    title: '처음 만난 자리',
    topic: '자기소개',
    estimatedMinutes: 10,
    content: const LessonContentModel(
      reading: ReadingModel(script: []),
      questions: [],
    ),
    vocabItems: vocabItems,
    grammarItems: grammarItems,
  );
}
