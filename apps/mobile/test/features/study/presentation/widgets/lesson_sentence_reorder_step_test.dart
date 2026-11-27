import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_sentence_reorder_step.dart';

const _question = LessonQuestionModel(
  order: 3,
  type: 'SENTENCE_REORDER',
  prompt: "'나는 하지 않습니다'를 올바른 순서로 배열하세요.",
  tokens: ['は', 'は', 'しません'],
  explanation: '문장 끝에 부정 표현을 놓아요.',
);

void main() {
  testWidgets('restored duplicate tokens occupy independent slots', (
    tester,
  ) async {
    List<String>? selected;
    List<String>? available;
    List<String>? submitted;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LessonSentenceReorderStep(
            questions: const [_question],
            currentIndex: 0,
            vocabItems: const [],
            shuffledBank: const ['は', '私', 'は', 'しません'],
            initialSelected: const ['は'],
            initialAvailable: const ['私', 'は', 'しません'],
            onDraftChanged: (newSelected, newAvailable) {
              selected = newSelected;
              available = newAvailable;
            },
            onAnswer: (answer) {
              submitted = answer['submittedOrder'] as List<String>;
            },
          ),
        ),
      ),
    );

    final incomplete = find.widgetWithText(FilledButton, '다음 학습');
    expect(tester.widget<FilledButton>(incomplete).onPressed, isNull);
    expect(find.text('나는 하지 않습니다'), findsOneWidget);
    expect(find.text('문장 끝에 부정 표현을 놓아요.'), findsNothing);
    await tester.tap(find.text('힌트 보기'));
    await tester.pumpAndSettle();
    expect(find.text('문장 끝에 부정 표현을 놓아요.'), findsOneWidget);
    await tester.tap(find.text('힌트 숨기기'));
    await tester.pumpAndSettle();
    final placed = find.byKey(const ValueKey('bank-slot-0'));
    final duplicate = find.byKey(const ValueKey('bank-slot-2'));
    expect(tester.widget<Semantics>(placed).properties.enabled, isFalse);
    expect(tester.widget<Semantics>(duplicate).properties.enabled, isTrue);

    await tester.tap(duplicate);
    await tester.pump();
    expect(selected, ['は', 'は']);
    expect(available, ['私', 'しません']);
    final first = find.byKey(const ValueKey('answer-target-0'));
    final second = find.byKey(const ValueKey('answer-target-1'));
    expect(tester.getTopLeft(first).dy, tester.getTopLeft(second).dy);
    expect(
        tester.getTopLeft(second).dx, greaterThan(tester.getTopLeft(first).dx));

    await tester.tap(first);
    await tester.pump();
    expect(available, ['私', 'しません', 'は']);
    expect(tester.widget<Semantics>(placed).properties.enabled, isTrue);
    expect(tester.widget<Semantics>(duplicate).properties.enabled, isFalse);

    await tester.tap(placed);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('bank-slot-3')));
    await tester.pump();
    final confirm = find.widgetWithText(FilledButton, '정답 확인');
    await tester.tap(confirm);
    await tester.pump();
    expect(submitted, ['は', 'は', 'しません']);
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
  });

  testWidgets('a narrow screen can scroll tokens with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 520);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const tokens = [
      '日本語の勉強を',
      '毎日忘れないように',
      '続けています',
      '先生に',
      '昨日の午後',
      '学校で',
    ];
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: LessonSentenceReorderStep(
            questions: const [
              LessonQuestionModel(
                order: 8,
                type: 'SENTENCE_REORDER',
                prompt: '긴 문장도 작은 화면에서 읽고 토큰을 골라 배열할 수 있어야 합니다.',
                tokens: tokens,
              ),
            ],
            currentIndex: 0,
            vocabItems: const [],
            shuffledBank: tokens,
            onAnswer: (_) {},
          ),
        ),
      ),
    );
    final last = find.byKey(const ValueKey('bank-slot-5'));
    await tester.ensureVisible(last);
    await tester.pump();
    expect(last.hitTestable(), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '다음 학습').hitTestable(),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
