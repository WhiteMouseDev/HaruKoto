import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_grammar_learning_step.dart';

void main() {
  group('LessonGrammarLearningStep', () {
    testWidgets('deduplicates grammar pattern variants before advancing',
        (tester) async {
      var nextCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonGrammarLearningStep(
              grammarItems: const [
                GrammarItemModel(
                  id: 'grammar-1',
                  pattern: '〜です',
                  meaningKo: '~입니다 / ~이에요',
                  explanation: '정중한 단정 표현',
                ),
                GrammarItemModel(
                  id: 'grammar-2',
                  pattern: '~ です',
                  meaningKo: '~입니다 / ~이에요',
                  explanation: '정중한 단정 표현',
                ),
                GrammarItemModel(
                  id: 'grammar-3',
                  pattern: '～です',
                  meaningKo: '~입니다 / ~이에요',
                  explanation: '정중한 단정 표현',
                ),
                GrammarItemModel(
                  id: 'grammar-4',
                  pattern: '〜ます',
                  meaningKo: '~합니다',
                  explanation: '정중한 동사 표현',
                ),
              ],
              onNext: () {
                nextCount += 1;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('문법 1/2'), findsOneWidget);
      expect(find.text('〜です'), findsOneWidget);
      expect(find.text('~ です'), findsNothing);
      expect(find.text('～です'), findsNothing);

      await tester.tap(find.text('다음 문법'));
      await tester.pumpAndSettle();

      expect(find.text('문법 2/2'), findsOneWidget);
      expect(find.text('〜ます'), findsOneWidget);

      await tester.tap(find.text('대화 읽기로'));
      await tester.pump();

      expect(nextCount, 1);
    });
  });
}
