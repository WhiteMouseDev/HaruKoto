import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_context_preview_step.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_vocab_preview_row.dart';

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

    testWidgets('shows Figma vocab rows and opens the full list',
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
                  VocabItemModel(
                    id: 'vocab-6',
                    word: '駅',
                    reading: 'えき',
                    meaningKo: '역',
                    partOfSpeech: 'noun',
                  ),
                  VocabItemModel(
                    id: 'duplicate',
                    word: '駅',
                    reading: 'えき',
                    meaningKo: '정거장',
                    partOfSpeech: 'noun',
                  ),
                ],
              ),
              jlptLevel: 'N4',
              stationNo: 2,
              onNext: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('N4'), findsOneWidget);
      expect(find.text('2번 역 · 1번째 레슨'), findsOneWidget);
      expect(find.text('10분'), findsOneWidget);
      expect(find.text('이번 레슨에서는'), findsOneWidget);
      expect(find.text('핵심 단어 미리보기'), findsOneWidget);
      expect(find.text('총 6개'), findsOneWidget);
      expect(find.byType(LessonVocabPreviewRow), findsNWidgets(5));

      final word = tester.getRect(find.text('私'));
      final reading = tester.getRect(find.text('わたし'));
      final meaning = tester.getRect(find.text('저'));
      expect(reading.left, greaterThan(word.right));
      expect(reading.center.dy, closeTo(word.center.dy, 2));
      expect(meaning.top, greaterThan(word.bottom));

      final allVocab = find.text('전체 6개 보기');
      await tester.ensureVisible(allVocab);
      await tester.tap(allVocab);
      await tester.pumpAndSettle();

      expect(find.text('배울 단어 6개'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('駅'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('駅'), findsOneWidget);
      expect(find.text('정거장'), findsNothing);
    });

    testWidgets('wraps real lesson content at 2x with a usable start action',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var started = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 568),
                textScaler: TextScaler.linear(2),
              ),
              child: LessonContextPreviewStep(
                detail: _detailWithGrammar(
                  const [
                    GrammarItemModel(
                      id: 'grammar-long',
                      pattern: 'この練習で使う長い文法の例です',
                      meaningKo: '여러 줄에 걸쳐 표시되는 실제 문법의 설명입니다.',
                      explanation: '설명',
                    ),
                  ],
                  vocabItems: const [
                    VocabItemModel(
                      id: 'vocab-long',
                      word: '繰り返して確認する',
                      reading: 'くりかえしてかくにんする',
                      meaningKo: '몇 번이고 반복해서 충분히 익힐 때까지 다시 확인하다',
                      partOfSpeech: 'expression',
                    ),
                  ],
                  estimatedMinutes: 0,
                ),
                onNext: () => started = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('레슨 1'), findsOneWidget);
      expect(find.text('0분'), findsNothing);
      await tester.ensureVisible(find.text('배울 문법'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('학습 시작'));
      expect(started, isTrue);
    });
  });
}

LessonDetailModel _detailWithGrammar(
  List<GrammarItemModel> grammarItems, {
  List<VocabItemModel> vocabItems = const [],
  int estimatedMinutes = 10,
}) {
  return LessonDetailModel(
    id: 'lesson-1',
    lessonNo: 1,
    chapterLessonNo: 1,
    title: '처음 만난 자리',
    topic: '자기소개',
    estimatedMinutes: estimatedMinutes,
    content: const LessonContentModel(
      reading: ReadingModel(script: []),
      questions: [],
    ),
    vocabItems: vocabItems,
    grammarItems: grammarItems,
  );
}
