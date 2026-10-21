import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_result_model.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/wrong_answer_list.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final quizType in ['VOCABULARY', 'GRAMMAR']) {
      testWidgets(
          'wrong-answer header fits 320px at 200% text in $brightness for $quizType',
          (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: brightness),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: WrongAnswerList(
                quizType: quizType,
                wrongAnswers: const [
                  WrongAnswerModel(
                    questionId: 'wrong-1',
                    word: '学生',
                    meaningKo: '학생',
                  ),
                ],
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(
          find.text('틀린 ${quizType == 'GRAMMAR' ? '문법' : '단어'} 1개'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
