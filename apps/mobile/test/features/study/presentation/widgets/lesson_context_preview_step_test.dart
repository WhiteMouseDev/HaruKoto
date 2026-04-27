import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_context_preview_step.dart';

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
                  id: 'grammar-1',
                  pattern: '〜です',
                  meaningKo: '~입니다 / ~이에요',
                  explanation: '정중한 단정 표현',
                ),
                const GrammarItemModel(
                  id: 'grammar-2',
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
      expect(find.text('〜ます'), findsOneWidget);
      expect(find.text('+0개'), findsNothing);
    });
  });
}

LessonDetailModel _detailWithGrammar(List<GrammarItemModel> grammarItems) {
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
    vocabItems: const [],
    grammarItems: grammarItems,
  );
}
