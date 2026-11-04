import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_result_question_card.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_result_score_summary.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_result_step.dart';

void main() {
  testWidgets('option ID becomes answer text and authoritative explanation',
      (tester) async {
    await _card(tester, _wrongChoice, _choice);
    expect(find.text('학생'), findsOneWidget);
    expect(find.text('a'), findsNothing);
    expect(find.text('학생이라는 뜻이에요.'), findsOneWidget);
    expect(find.text('제출 당시 상태: 학습 중'), findsOneWidget);
    expect(find.textContaining('SRS'), findsNothing);
  });

  testWidgets('reorder displays the complete submitted correct sentence',
      (tester) async {
    await _card(tester, _wrongSentence, _sentence);
    expect(find.text('완성 문장'), findsOneWidget);
    expect(find.text('私は学生です'), findsOneWidget);
    expect(find.text('は는 화제를 나타내요.'), findsOneWidget);
  });

  testWidgets(
      'historical schedule is an absolute Korean date without current-due claims',
      (tester) async {
    await _card(
        tester,
        const QuestionResultModel(
            order: 1,
            isCorrect: false,
            correctAnswer: 'a',
            nextReviewAt: '2020-12-31T15:01:00Z'),
        _choice);
    expect(find.text('제출 당시 복습 예정: 2021년 1월 1일 00:01 (한국 시간)'), findsOneWidget);
    expect(find.textContaining('분 후'), findsNothing);
    expect(find.textContaining('지금'), findsNothing);
  });

  testWidgets(
      'legacy absent metadata and unsupported timestamps do not invent schedule',
      (tester) async {
    for (final value in [null, 'not-an-iso-time', '2026-11-03T09:00:00']) {
      await _card(
          tester,
          QuestionResultModel(order: 1, isCorrect: false, nextReviewAt: value),
          _choice);
      expect(find.text('정답 정보를 확인할 수 없어요.'), findsOneWidget);
      expect(find.text('이 문항에는 별도 해설이 없어요.'), findsOneWidget);
      expect(find.textContaining('제출 당시 복습 예정:'), findsNothing);
      expect(find.text('새 상세의 다른 해설'), findsNothing);
      if (value != null) expect(find.text(value), findsNothing);
    }
  });

  testWidgets(
      'missing and mismatched question never use another question content',
      (tester) async {
    for (final question in [null, _sentence]) {
      await _card(tester, _wrongChoice, question);
      expect(find.text('이 문항의 원문을 확인할 수 없어요.'), findsOneWidget);
      expect(find.text('정답 정보를 확인할 수 없어요.'), findsOneWidget);
      expect(find.text(_sentence.prompt), findsNothing);
      expect(find.text('학생이라는 뜻이에요.'), findsOneWidget);
    }
  });

  testWidgets(
      'wrong-only defaults and all view preserve source order and never invoke actions',
      (tester) async {
    _largeSurface(tester);
    final results = [_wrongSentence, _correctChoice, _wrongChoice];
    final original = List<QuestionResultModel>.of(results);
    var done = 0;
    var retry = 0;
    final result = LessonSubmitResultModel(
        scoreCorrect: 1, scoreTotal: 3, results: results, status: 'COMPLETED');
    await _step(tester, result, onDone: () => done++, onRetry: () => retry++);
    expect(
        tester
            .widget<ChoiceChip>(
                find.byKey(const ValueKey('lesson-results-wrong')))
            .selected,
        isTrue);
    expect(_visibleOrders(tester), [2, 1]);
    await tester.tap(find.byKey(const ValueKey('lesson-results-all')));
    await tester.pumpAndSettle();
    expect(_visibleOrders(tester), [2, 3, 1]);
    await tester.tap(find.byKey(const ValueKey('lesson-results-wrong')));
    await tester.pumpAndSettle();
    expect(_visibleOrders(tester), [2, 1]);
    expect(results, orderedEquals(original));
    expect(done, 0);
    expect(retry, 0);
    await tester.tap(find.text('학습으로 돌아가기'));
    await tester.pump();
    expect(done, 1);
    await tester.tap(find.text('레슨 전체 다시 풀기'));
    await tester.pump();
    expect(retry, 1);
  });

  testWidgets(
      'all-correct defaults to all and wrong filter explains empty state',
      (tester) async {
    _largeSurface(tester);
    await _step(
        tester,
        const LessonSubmitResultModel(
            scoreCorrect: 1,
            scoreTotal: 1,
            results: [_correctChoice],
            status: 'COMPLETED'));
    expect(
        tester
            .widget<ChoiceChip>(
                find.byKey(const ValueKey('lesson-results-all')))
            .selected,
        isTrue);
    expect(_visibleOrders(tester), [3]);
    await tester.tap(find.byKey(const ValueKey('lesson-results-wrong')));
    await tester.pumpAndSettle();
    expect(find.text('틀린 문항이 없어요. 전체 보기에서 정답을 다시 확인해 보세요.'), findsOneWidget);
    expect(find.byType(LessonResultQuestionCard), findsNothing);
    await tester.tap(find.byKey(const ValueKey('lesson-results-all')));
    await tester.pumpAndSettle();
    expect(_visibleOrders(tester), [3]);
  });

  testWidgets('zero results are not celebrated as a perfect score',
      (tester) async {
    _largeSurface(tester);
    await _step(
        tester,
        const LessonSubmitResultModel(
            scoreCorrect: 0, scoreTotal: 0, results: [], status: 'COMPLETED'));
    expect(
        tester
            .widget<LessonResultScoreBadge>(find.byType(LessonResultScoreBadge))
            .isPerfect,
        isFalse);
    expect(find.text('문항별 결과가 없어 정답을 표시할 수 없어요.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'missing and duplicate question orders remain unavailable without first fallback',
      (tester) async {
    _largeSurface(tester);
    final detail = _detail([_choice, _choice]);
    await _step(
        tester,
        const LessonSubmitResultModel(
            scoreCorrect: 0,
            scoreTotal: 2,
            results: [
              _wrongChoice,
              QuestionResultModel(
                  order: 99, isCorrect: false, correctAnswer: 'a')
            ],
            status: 'COMPLETED'),
        detail: detail);
    expect(find.text('이 문항의 원문을 확인할 수 없어요.'), findsNWidgets(2));
    expect(find.text(_choice.prompt), findsNothing);
    expect(find.text('학생'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'duplicate result orders keep unique cards without guessing answer text',
      (tester) async {
    _largeSurface(tester);
    await _step(
        tester,
        const LessonSubmitResultModel(
            scoreCorrect: 0,
            scoreTotal: 2,
            results: [_wrongChoice, _wrongChoice],
            status: 'COMPLETED'));
    expect(find.byType(LessonResultQuestionCard), findsNWidgets(2));
    expect(find.text('이 문항의 원문을 확인할 수 없어요.'), findsNWidgets(2));
    expect(find.text('학생'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a new lesson result resets the previous filter choice',
      (tester) async {
    _largeSurface(tester);
    await _step(
        tester,
        const LessonSubmitResultModel(
            scoreCorrect: 0,
            scoreTotal: 1,
            results: [_wrongChoice],
            status: 'COMPLETED'));
    await tester.tap(find.byKey(const ValueKey('lesson-results-all')));
    await tester.pumpAndSettle();
    await _step(
        tester,
        const LessonSubmitResultModel(
            scoreCorrect: 0,
            scoreTotal: 2,
            results: [_wrongChoice, _wrongSentence],
            status: 'COMPLETED'));
    expect(
        tester
            .widget<ChoiceChip>(
                find.byKey(const ValueKey('lesson-results-wrong')))
            .selected,
        isTrue);
  });

  for (final brightness in Brightness.values) {
    testWidgets('result and actions fit320px with200% text in $brightness',
        (tester) async {
      tester.view.physicalSize = const Size(320, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _step(
          tester,
          const LessonSubmitResultModel(
              scoreCorrect: 0,
              scoreTotal: 2,
              results: [_wrongChoice, _wrongSentence],
              status: 'COMPLETED',
              srsItemsRegistered: 2),
          brightness: brightness,
          textScale: 2);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -1400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('학습으로 돌아가기'), findsOneWidget);
    });
  }
}

List<int> _visibleOrders(WidgetTester tester) => tester
    .widgetList<LessonResultQuestionCard>(find.byType(LessonResultQuestionCard))
    .map((card) => card.result.order)
    .toList();
void _largeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(500, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _card(WidgetTester tester, QuestionResultModel result,
    LessonQuestionModel? question) async {
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: SingleChildScrollView(
              child: LessonResultQuestionCard(
                  result: result, question: question)))));
  await tester.pumpAndSettle();
}

Future<void> _step(WidgetTester tester, LessonSubmitResultModel result,
    {LessonDetailModel? detail,
    VoidCallback? onDone,
    VoidCallback? onRetry,
    Brightness brightness = Brightness.light,
    double textScale = 1}) async {
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(brightness: brightness),
    builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!),
    home: Scaffold(
        body: LessonResultStep(
            result: result,
            detail: detail ?? _detail([_choice, _sentence, _thirdQuestion]),
            onDone: onDone ?? () {},
            onRetry: onRetry ?? () {})),
  ));
  await tester.pumpAndSettle();
}

LessonDetailModel _detail(
        List<LessonQuestionModel> questions) =>
    LessonDetailModel(
        id: 'lesson-1',
        lessonNo: 1,
        chapterLessonNo: 1,
        title: '처음 만난 자리',
        topic: '소개',
        estimatedMinutes: 10,
        content: LessonContentModel(
            reading: const ReadingModel(script: []), questions: questions),
        vocabItems: [],
        grammarItems: []);
const _choice = LessonQuestionModel(
    order: 1,
    type: 'VOCAB_MCQ',
    prompt: '「学生」の 뜻은?',
    options: [
      QuizOptionModel(id: 'b', text: '선생님'),
      QuizOptionModel(id: 'a', text: '학생')
    ],
    explanation: '새 상세의 다른 해설');
const _thirdQuestion = LessonQuestionModel(
    order: 3,
    type: 'VOCAB_MCQ',
    prompt: '「先生」の 뜻은?',
    options: [QuizOptionModel(id: 'a', text: '선생님')]);
const _sentence = LessonQuestionModel(
    order: 2,
    type: 'SENTENCE_REORDER',
    prompt: '나는 학생입니다',
    tokens: ['です', '学生', '私は']);
const _wrongChoice = QuestionResultModel(
    order: 1,
    isCorrect: false,
    correctAnswer: 'a',
    explanation: '학생이라는 뜻이에요.',
    stateBefore: 'UNSEEN',
    stateAfter: 'LEARNING');
const _wrongSentence = QuestionResultModel(
    order: 2,
    isCorrect: false,
    correctOrder: ['私', 'は', '学生', 'です'],
    explanation: 'は는 화제를 나타내요.');
const _correctChoice = QuestionResultModel(
    order: 3, isCorrect: true, correctAnswer: 'a', explanation: '선생님이라는 뜻이에요.');
