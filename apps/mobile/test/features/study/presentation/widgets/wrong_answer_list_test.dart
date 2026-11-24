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

  testWidgets('redesigned wrong details stay readable and saveable at 2x',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final saved = <String>[];
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: WrongAnswerList(
            redesigned: true,
            quizType: 'VOCABULARY',
            onSaveToWordbook: (item) => saved.add(item.questionId),
            wrongAnswers: const [
              WrongAnswerModel(
                questionId: 'q1',
                word: '明日の午前九時にお会いしましょう',
                reading: 'あしたのごぜんくじにおあいしましょう',
                meaningKo: '내일 오전 아홉 시에 만나요',
                exampleSentence: '駅の前で会います。',
                exampleTranslation: '역 앞에서 만나요.',
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.tap(find.text('틀린 문제 1개'));
    await tester.pumpAndSettle();

    expect(find.text('내일 오전 아홉 시에 만나요'), findsOneWidget);
    expect(find.text('역 앞에서 만나요.'), findsOneWidget);
    expect(find.byTooltip('음성 듣기'), findsOneWidget);
    await tester.tap(find.byTooltip('단어장에 저장'));
    expect(saved, ['q1']);
    expect(tester.takeException(), isNull);
  });
}
