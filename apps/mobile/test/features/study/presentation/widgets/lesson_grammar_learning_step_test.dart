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
      final nextStage = find.widgetWithText(FilledButton, '다음학습');
      expect(tester.widget<FilledButton>(nextStage).onPressed, isNull);
      expect(find.text('정중한 단정 표현'), findsOneWidget);

      await tester.tap(find.text('다음 문법'));
      await tester.pumpAndSettle();

      expect(find.text('문법 2/2'), findsOneWidget);
      expect(find.text('〜ます'), findsOneWidget);
      expect(find.text('정중한 동사 표현'), findsOneWidget);
      final nextItem = find.widgetWithText(OutlinedButton, '다음 문법');
      expect(tester.widget<OutlinedButton>(nextItem).onPressed, isNull);

      await tester.tap(nextStage);
      await tester.pump();

      expect(nextCount, 1);
    });

    testWidgets('scrolls long content at two-times text size', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var nextCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: LessonGrammarLearningStep(
              grammarItems: [
                GrammarItemModel(
                  id: 'grammar-1',
                  pattern: '〜たほうがいい',
                  meaningKo: '~ 하는 편이 좋다',
                  explanation: List.filled(
                    8,
                    '동사의 た형 뒤에 붙여 상대에게 부드럽게 조언하는 표현입니다.',
                  ).join(' '),
                ),
              ],
              onNext: () => nextCount++,
            ),
          ),
        ),
      );

      final explanation = find.textContaining('동사의 た형');
      final next = find.widgetWithText(FilledButton, '다음학습');
      await tester.ensureVisible(explanation);
      await tester.pumpAndSettle();
      expect(explanation, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(next);
      expect(nextCount, 1);
    });
  });
}
