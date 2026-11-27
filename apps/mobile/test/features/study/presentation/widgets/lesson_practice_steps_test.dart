import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/constants/colors.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/domain/lesson_recognition_feedback.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_matching_game_step.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_recognition_check_step.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_sentence_reorder_step.dart';
import 'package:lucide_icons/lucide_icons.dart';

void main() {
  group('Lesson practice steps', () {
    testWidgets(
      'recognition allows reselection until the correct answer is confirmed',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final harness = _RecognitionHarness(question: _gradedQuestion);
        await harness.mount(tester);
        final confirm = find.widgetWithText(FilledButton, '정답 확인');
        final inactiveConfirm = tester.widget<FilledButton>(confirm);
        expect(inactiveConfirm.onPressed, isNull);
        expect(
            inactiveConfirm.style?.backgroundColor?.resolve({
              WidgetState.disabled,
            }),
            AppColors.redesignControl);
        final count = find.text('문제 1 / 1');
        final firstChoice = find.widgetWithText(OutlinedButton, '안녕하세요');
        final secondChoice = find.widgetWithText(OutlinedButton, '처음 뵙겠습니다');
        final firstPaint = tester.getRect(
          find.descendant(of: firstChoice, matching: find.byType(Material)),
        );
        final secondPaint = tester.getRect(
          find.descendant(of: secondChoice, matching: find.byType(Material)),
        );
        expect(firstPaint.left, 40);
        expect(firstPaint.width, 295);
        expect(firstPaint.height, 42);
        expect(secondPaint.top - firstPaint.bottom, 12);
        expect(tester.getSize(firstChoice).height, 48);
        expect(
          tester.getTopRight(count).dx,
          closeTo(tester.getTopRight(firstChoice).dx, 1),
        );

        await tester.tap(find.text('안녕하세요'));
        await tester.pumpAndSettle();
        expect(harness.selections, ['a']);
        _expectNeutralRecognition();
        final firstSelected = tester.widget<OutlinedButton>(firstChoice);
        expect(firstSelected.style?.backgroundColor?.resolve({}), Colors.white);
        expect(firstSelected.style?.side?.resolve({}),
            const BorderSide(color: AppColors.brandPink, width: 2));
        expect(
            tester
                .widget<FilledButton>(confirm)
                .style
                ?.backgroundColor
                ?.resolve({}),
            AppColors.redesignStrong);

        await tester.tap(find.text('처음 뵙겠습니다'));
        await tester.pumpAndSettle();
        expect(harness.selections, ['a', 'b']);
        expect(harness.confirmCalls, 0);
        expect(harness.nextCalls, 0);
        _expectNeutralRecognition();
        expect(find.text('첫 만남에서 쓰는 표현이에요.'), findsNothing);

        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(harness.confirmCalls, 1);
        expect(harness.nextCalls, 0);
        expect(find.text('정답이에요!'), findsOneWidget);
        expect(find.text('아쉬워요'), findsNothing);
        final graded = tester.widget<OutlinedButton>(secondChoice);
        expect(graded.onPressed, isNull);
        expect(graded.style?.backgroundColor?.resolve({WidgetState.disabled}),
            AppColors.quizCorrectBg);
        final next = find.widgetWithText(FilledButton, '다음 학습');
        expect(
            tester
                .widget<FilledButton>(next)
                .style
                ?.backgroundColor
                ?.resolve({}),
            AppColors.brandPink);

        await tester.tap(find.text('안녕하세요'));
        await tester.pumpAndSettle();
        expect(harness.selections, ['a', 'b']);
        expect(find.text('정답이에요!'), findsOneWidget);

        await tester.tap(find.text('다음 학습'));
        await tester.pumpAndSettle();
        expect(harness.nextCalls, 1);
        expect(harness.confirmCalls, 1);
      },
    );

    testWidgets(
      'recognition shows incorrect feedback only after confirmation',
      (tester) async {
        final harness = _RecognitionHarness(
          question: _gradedQuestion,
          questionCount: 2,
        );
        await harness.mount(tester);

        await tester.tap(find.text('안녕하세요'));
        await tester.pumpAndSettle();
        _expectNeutralRecognition();
        expect(find.text('정답: 처음 뵙겠습니다'), findsNothing);
        expect(find.text('첫 만남에서 쓰는 표현이에요.'), findsNothing);

        await tester.tap(find.text('정답 확인'));
        await tester.pumpAndSettle();
        expect(harness.selections, ['a']);
        expect(harness.confirmCalls, 1);
        expect(harness.nextCalls, 0);
        expect(find.text('정답이에요!'), findsNothing);
        expect(find.text('아쉬워요'), findsOneWidget);
        expect(find.text('정답: 처음 뵙겠습니다'), findsOneWidget);
        expect(find.text('첫 만남에서 쓰는 표현이에요.'), findsOneWidget);
        final gradedWrong = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, '안녕하세요'),
        );
        final gradedCorrect = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, '처음 뵙겠습니다'),
        );
        expect(
            gradedWrong.style?.backgroundColor?.resolve({WidgetState.disabled}),
            AppColors.quizWrongBg);
        expect(
            gradedCorrect.style?.backgroundColor
                ?.resolve({WidgetState.disabled}),
            AppColors.quizCorrectBg);
        final next = find.widgetWithText(FilledButton, '다음 문제');
        expect(
            tester
                .widget<FilledButton>(next)
                .style
                ?.backgroundColor
                ?.resolve({}),
            AppColors.redesignStrong);

        await tester.tap(find.text('다음 문제'));
        await tester.pumpAndSettle();
        expect(harness.nextCalls, 1);
        expect(harness.confirmCalls, 1);
      },
    );

    testWidgets(
      'server grading blocks advancement until feedback or failure and retries independently',
      (tester) async {
        final harness = _RecognitionHarness(
          question: _gradedQuestion,
          usesServerFeedback: true,
        );
        await harness.mount(tester);

        await tester.tap(find.text('안녕하세요'));
        await tester.pumpAndSettle();
        expect(find.text('정답 확인'), findsOneWidget);
        await tester.tap(find.text('정답 확인'));
        await tester.pumpAndSettle();

        final next = find.widgetWithText(FilledButton, '다음 학습');
        expect(harness.confirmCalls, 1);
        expect(find.text('채점 중…'), findsOneWidget);
        expect(find.text('아쉬워요'), findsNothing);
        expect(find.text('첫 만남에서 쓰는 표현이에요.'), findsNothing);
        expect(find.text('다시 확인'), findsNothing);
        expect(tester.widget<FilledButton>(next).onPressed, isNull);

        harness.finishFeedback();
        await tester.pumpAndSettle();
        expect(find.text('정오답을 확인하지 못했어요'), findsOneWidget);
        expect(find.text('채점 중…'), findsNothing);
        expect(tester.widget<FilledButton>(next).onPressed, isNotNull);
        await tester.tap(find.text('다시 확인'));
        await tester.pumpAndSettle();

        expect(harness.confirmCalls, 1);
        expect(harness.retryCalls, 1);
        expect(find.text('채점 중…'), findsOneWidget);
        expect(find.text('다시 확인'), findsNothing);
        expect(tester.widget<FilledButton>(next).onPressed, isNull);

        harness.finishFeedback(
            feedback: const LessonRecognitionFeedback(
          feedbackVersion: 'fixture-v1',
          questionOrder: 2,
          selectedAnswer: 'a',
          correctAnswer: 'b',
          isCorrect: false,
          explanation: '서버의 설명이에요.',
        ));
        await tester.pumpAndSettle();

        expect(find.text('아쉬워요'), findsOneWidget);
        expect(find.text('정답: 처음 뵙겠습니다'), findsOneWidget);
        expect(find.text('서버의 설명이에요.'), findsOneWidget);
        expect(find.text('첫 만남에서 쓰는 표현이에요.'), findsNothing);
        expect(find.text('다시 확인'), findsNothing);
        final wrong = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, '안녕하세요'),
        );
        final correct = tester.widget<OutlinedButton>(
          find.widgetWithText(OutlinedButton, '처음 뵙겠습니다'),
        );
        expect(wrong.style?.backgroundColor?.resolve({WidgetState.disabled}),
            AppColors.quizWrongBg);
        expect(correct.style?.backgroundColor?.resolve({WidgetState.disabled}),
            AppColors.quizCorrectBg);
        await tester.tap(next);
        expect(harness.nextCalls, 1);
        expect(harness.confirmCalls, 1);
      },
    );

    testWidgets(
      'unavailable server grading stops retry and allows advancement',
      (tester) async {
        final harness = _RecognitionHarness(
          question: _gradedQuestion,
          usesServerFeedback: true,
        );
        await harness.mount(tester);

        await tester.tap(find.text('안녕하세요'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('정답 확인'));
        await tester.pumpAndSettle();
        harness.finishFeedback(unavailable: true);
        await tester.pumpAndSettle();

        expect(find.text('지금은 채점할 수 없어요. 레슨 결과를 확인해 주세요.'), findsOneWidget);
        expect(find.text('정답이에요!'), findsNothing);
        expect(find.text('아쉬워요'), findsNothing);
        expect(find.text('채점 중…'), findsNothing);
        expect(find.text('다시 확인'), findsNothing);
        await tester.tap(find.widgetWithText(FilledButton, '다음 학습'));
        expect(harness.nextCalls, 1);
        expect(harness.confirmCalls, 1);
      },
    );

    testWidgets(
      'restored server-graded answers show cached feedback or offer manual retry',
      (tester) async {
        var harness = _RecognitionHarness(
          question: _gradedQuestion,
          usesServerFeedback: true,
          restoredAnswer: 'b',
          feedback: const LessonRecognitionFeedback(
            feedbackVersion: 'fixture-v1',
            questionOrder: 2,
            selectedAnswer: 'b',
            correctAnswer: 'b',
            isCorrect: true,
          ),
        );
        await harness.mount(tester);
        expect(find.text('정답이에요!'), findsOneWidget);
        expect(find.text('다시 확인'), findsNothing);
        expect(find.text('첫 만남에서 쓰는 표현이에요.'), findsNothing);
        expect(harness.confirmCalls, 0);

        harness = _RecognitionHarness(
          question: _gradedQuestion,
          usesServerFeedback: true,
          restoredAnswer: 'b',
        );
        await harness.mount(tester);
        expect(find.text('정오답을 확인하지 못했어요'), findsOneWidget);
        expect(find.text('채점 중…'), findsNothing);
        expect(find.text('다시 확인'), findsOneWidget);
        expect(harness.retryCalls, 0);
        await tester.tap(find.widgetWithText(FilledButton, '다음 학습'));
        expect(harness.nextCalls, 1);
        expect(harness.confirmCalls, 0);
      },
    );

    testWidgets(
      'recognition without an answer key fits a compact large-text screen',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const lastOption = '서로 처음 만난 자리에서 자신의 이름을 먼저 말하며 인사하는 표현입니다.';
        const explanation = '대화의 상황과 앞뒤 표현을 살펴보면서 문장에 어울리는 뜻을 확인해 보세요.';
        final harness = _RecognitionHarness(
          question: const LessonQuestionModel(
            order: 7,
            type: 'CONTEXT_CLOZE',
            prompt: '두 사람이 일상에서 처음 만나 서로 어떤 이야기를 나누는 장면인지 읽고, '
                '아래 설명 중 대화의 앞뒤 흐름과 가장 잘 어울리는 보기를 골라 보세요.',
            options: [
              QuizOptionModel(id: 'a', text: '여러 번 만난 사람이 헤어지기 전에 사용하는 표현입니다.'),
              QuizOptionModel(
                id: 'b',
                text: '약속한 시간을 바꿀 수 있는지 상대방에게 조심스럽게 묻습니다.',
              ),
              QuizOptionModel(
                id: 'c',
                text: '오늘 어디에서 만나기로 했는지 친구에게 확인하는 표현입니다.',
              ),
              QuizOptionModel(id: 'd', text: lastOption),
            ],
            explanation: explanation,
          ),
          optionOrder: const ['a', 'b', 'c', 'd'],
        );
        await harness.mount(tester, textScale: 2);

        final confirm = find.widgetWithText(FilledButton, '답안 확인');
        expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(find.text(lastOption), 120);
        await tester.tap(find.text(lastOption));
        await tester.pumpAndSettle();
        expect(harness.selections, ['d']);
        _expectNeutralRecognition();
        expect(confirm.hitTestable(), findsOneWidget);
        expect(find.text('이전').hitTestable(), findsOneWidget);

        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(harness.confirmCalls, 1);
        expect(harness.nextCalls, 0);
        await tester.scrollUntilVisible(find.text(explanation), 120);
        expect(find.text('답안을 확인했어요'), findsOneWidget);
        expect(find.text('정답이에요!'), findsNothing);
        expect(find.text('아쉬워요'), findsNothing);
        expect(tester.takeException(), isNull);

        final next = find.text('다음 학습').hitTestable();
        expect(next, findsOneWidget);
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(harness.nextCalls, 1);
        expect(harness.confirmCalls, 1);
        expect(harness.selections, ['d']);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
        'matching enables the next step only after all pairs are matched',
        (tester) async {
      var completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonMatchingGameStep(
              vocabItems: const [
                VocabItemModel(
                  id: 'vocab-1',
                  word: '犬',
                  reading: 'いぬ',
                  meaningKo: '개',
                  partOfSpeech: 'noun',
                ),
                VocabItemModel(
                  id: 'vocab-2',
                  word: '猫',
                  reading: 'ねこ',
                  meaningKo: '고양이',
                  partOfSpeech: 'noun',
                ),
              ],
              onComplete: () {
                completed = true;
              },
            ),
          ),
        ),
      );

      final next = find.widgetWithText(FilledButton, '다음 학습');
      final inactiveNext = tester.widget<FilledButton>(next);
      const disabled = {WidgetState.disabled};
      expect(inactiveNext.onPressed, isNull);
      expect(inactiveNext.style?.foregroundColor?.resolve(disabled),
          const Color(0xFF999999));
      expect(inactiveNext.style?.iconColor?.resolve(disabled),
          const Color(0xFFA5A5AF));
      final capsule = tester.getRect(next);
      final chevron = find.byIcon(LucideIcons.chevronRight);
      expect(capsule.height, 48);
      expect(tester.getRect(chevron).height, 20);
      expect(tester.getCenter(chevron).dy, capsule.center.dy);
      expect(tester.getCenter(find.text('다음 학습')).dy, capsule.center.dy - 1);

      await tester.tap(find.text('犬'));
      await tester.pump();
      await tester.tap(find.text('개'));
      await tester.pump();

      await tester.tap(find.text('猫'));
      await tester.pump();
      await tester.tap(find.text('고양이'));
      await tester.pump(const Duration(milliseconds: 501));

      expect(completed, isFalse);
      expect(tester.widget<FilledButton>(next).onPressed, isNotNull);
      await tester.tap(next);
      expect(completed, isTrue);
    });

    testWidgets('sentence reorder step submits selected token order',
        (tester) async {
      Map<String, dynamic>? answer;
      var submissions = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonSentenceReorderStep(
              questions: const [
                LessonQuestionModel(
                  order: 5,
                  type: 'SENTENCE_REORDER',
                  prompt: '문장을 완성하세요',
                  tokens: ['私は', '学生', 'です'],
                ),
              ],
              currentIndex: 0,
              vocabItems: const [
                VocabItemModel(
                  id: 'vocab-1',
                  word: '先生',
                  reading: 'せんせい',
                  meaningKo: '선생님',
                  partOfSpeech: 'noun',
                ),
              ],
              onAnswer: (value) {
                submissions++;
                answer = value;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('私は'));
      await tester.pump();
      await tester.tap(find.text('学生'));
      await tester.pump();
      await tester.tap(find.text('です'));
      await tester.pump();
      await tester.tap(find.text('정답 확인'));
      expect(answer?['order'], 5);
      expect(answer?['submittedOrder'], ['私は', '学生', 'です']);
      // A second tap before a frame and after the former animation delay
      // cannot submit the same question again.
      await tester.tap(find.text('정답 확인'));
      await tester.pump(const Duration(milliseconds: 301));
      expect(submissions, 1);
      expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, '정답 확인'))
              .onPressed,
          isNull);
    });

    testWidgets('sentence reorder starts with a blank answer canvas',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonSentenceReorderStep(
              questions: const [
                LessonQuestionModel(
                  order: 5,
                  type: 'SENTENCE_REORDER',
                  prompt: '문장을 완성하세요',
                  tokens: ['私は', '学生', 'です'],
                ),
              ],
              currentIndex: 0,
              vocabItems: const [],
              onAnswer: (_) {},
            ),
          ),
        ),
      );

      final answerWell =
          find.byKey(const ValueKey('sentence-reorder-answer-well'));
      expect(answerWell, findsOneWidget);
      expect(find.descendant(of: answerWell, matching: find.byType(Text)),
          findsNothing);
      final next = find.widgetWithText(FilledButton, '다음 학습');
      expect(tester.widget<FilledButton>(next).onPressed, isNull);
    });

    testWidgets('sentence reorder compacts after removing selected token',
        (tester) async {
      Map<String, dynamic>? answer;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonSentenceReorderStep(
              questions: const [
                LessonQuestionModel(
                  order: 5,
                  type: 'SENTENCE_REORDER',
                  prompt: '문장을 완성하세요',
                  tokens: ['私は', '学生', 'です'],
                ),
              ],
              currentIndex: 0,
              vocabItems: const [],
              onAnswer: (value) => answer = value,
            ),
          ),
        ),
      );

      await tester.tap(find.text('私は'));
      await tester.pump();
      await tester.tap(find.text('学生'));
      await tester.pump();

      expect(
        find.byWidgetPredicate(
          (widget) => widget is LongPressDraggable<int>,
        ),
        findsNWidgets(2),
      );
      final firstTargetTopLeft = tester.getTopLeft(
        find.byKey(const ValueKey('answer-target-0')),
      );
      final secondTargetTopLeft = tester.getTopLeft(
        find.byKey(const ValueKey('answer-target-1')),
      );
      expect(secondTargetTopLeft.dy, firstTargetTopLeft.dy);
      expect(secondTargetTopLeft.dx, greaterThan(firstTargetTopLeft.dx));
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('answer-target-0')));
      await tester.pump();

      expect(find.byKey(const ValueKey('answer-target-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('answer-target-1')), findsNothing);

      await tester.tap(find.text('です'));
      await tester.pump();
      await tester.tap(find.text('私は'));
      await tester.pump();
      await tester.tap(find.text('정답 확인'));
      await tester.pump(const Duration(milliseconds: 301));

      expect(answer?['submittedOrder'], ['学生', 'です', '私は']);
    });
  });
}

const _gradedQuestion = LessonQuestionModel(
  order: 2,
  type: 'VOCAB_MCQ',
  prompt: '「はじめまして」の 의미는?',
  options: [
    QuizOptionModel(id: 'a', text: '안녕하세요'),
    QuizOptionModel(id: 'b', text: '처음 뵙겠습니다'),
  ],
  correctAnswer: 'b',
  explanation: '첫 만남에서 쓰는 표현이에요.',
);

void _expectNeutralRecognition() {
  expect(find.text('정답이에요!'), findsNothing);
  expect(find.text('아쉬워요'), findsNothing);
  expect(find.text('답안을 확인했어요'), findsNothing);
  expect(find.text('다음 학습'), findsNothing);
  expect(find.text('다음 문제'), findsNothing);
}

class _RecognitionHarness {
  _RecognitionHarness({
    required this.question,
    this.questionCount = 1,
    this.optionOrder = const ['a', 'b'],
    this.usesServerFeedback = false,
    this.restoredAnswer,
    LessonRecognitionFeedback? feedback,
  })  : _selectedOptionId = restoredAnswer,
        _feedback = feedback;

  final LessonQuestionModel question;
  final int questionCount;
  final List<String> optionOrder;
  final bool usesServerFeedback;
  final String? restoredAnswer;
  final List<String> selections = [];
  String? _selectedOptionId;
  LessonRecognitionFeedback? _feedback;
  bool _feedbackPending = false;
  bool _feedbackUnavailable = false;
  late StateSetter _setState;
  int confirmCalls = 0;
  int nextCalls = 0;
  int retryCalls = 0;

  void finishFeedback({
    LessonRecognitionFeedback? feedback,
    bool unavailable = false,
  }) {
    _setState(() {
      _feedback = feedback;
      _feedbackPending = false;
      _feedbackUnavailable = unavailable;
    });
  }

  Future<void> mount(WidgetTester tester, {double textScale = 1}) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          appBar: AppBar(toolbarHeight: 62),
          bottomNavigationBar: const SizedBox(height: 68),
          body: StatefulBuilder(
            builder: (context, setState) {
              _setState = setState;
              return LessonRecognitionCheckStep(
                question: question,
                currentIndex: 0,
                questionCount: questionCount,
                optionOrder: optionOrder,
                selectedOptionId: _selectedOptionId,
                confirmed: restoredAnswer != null || confirmCalls > 0,
                usesServerFeedback: usesServerFeedback,
                feedbackPending: _feedbackPending,
                feedbackUnavailable: _feedbackUnavailable,
                feedback: _feedback,
                onSelectionChanged: (id) => setState(() {
                  selections.add(id);
                  _selectedOptionId = id;
                }),
                onConfirm: () => setState(() {
                  confirmCalls++;
                  _feedbackPending = usesServerFeedback;
                }),
                onRetryFeedback: () => setState(() {
                  retryCalls++;
                  _feedbackPending = true;
                }),
                onNext: () => nextCalls++,
                onPrevious: () {},
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}
