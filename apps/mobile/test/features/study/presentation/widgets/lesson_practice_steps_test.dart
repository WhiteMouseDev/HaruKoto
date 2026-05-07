import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_matching_game_step.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_recognition_check_step.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_sentence_reorder_step.dart';

void main() {
  group('Lesson practice steps', () {
    testWidgets('recognition step submits the selected option', (tester) async {
      Map<String, dynamic>? answer;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonRecognitionCheckStep(
              questions: const [
                LessonQuestionModel(
                  order: 2,
                  type: 'VOCAB_MCQ',
                  prompt: '「はじめまして」の 의미는?',
                  options: [
                    QuizOptionModel(id: 'a', text: '안녕하세요'),
                    QuizOptionModel(id: 'b', text: '처음 뵙겠습니다'),
                  ],
                  correctAnswer: 'b',
                ),
              ],
              currentIndex: 0,
              totalSteps: 8,
              onAnswer: (value) => answer = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('처음 뵙겠습니다'));
      await tester.pump();

      expect(answer, isNull);
      expect(find.text('정답이에요!'), findsOneWidget);
      expect(find.text('다음으로'), findsOneWidget);

      await tester.tap(find.text('다음으로'));
      await tester.pump();

      expect(answer?['order'], 2);
      expect(answer?['selectedAnswer'], 'b');
    });

    testWidgets('recognition step distinguishes incorrect feedback',
        (tester) async {
      Map<String, dynamic>? answer;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonRecognitionCheckStep(
              questions: const [
                LessonQuestionModel(
                  order: 2,
                  type: 'VOCAB_MCQ',
                  prompt: '「はじめまして」の 의미는?',
                  options: [
                    QuizOptionModel(id: 'a', text: '안녕하세요'),
                    QuizOptionModel(id: 'b', text: '처음 뵙겠습니다'),
                  ],
                  correctAnswer: 'b',
                  explanation: '첫 만남에서 쓰는 표현이에요.',
                ),
              ],
              currentIndex: 0,
              totalSteps: 8,
              onAnswer: (value) => answer = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('안녕하세요'));
      await tester.pump();

      expect(answer, isNull);
      expect(find.text('아쉬워요'), findsOneWidget);
      expect(find.text('정답: 처음 뵙겠습니다'), findsOneWidget);
      expect(find.text('첫 만남에서 쓰는 표현이에요.'), findsOneWidget);
      expect(find.text('다음으로'), findsOneWidget);

      await tester.tap(find.text('다음으로'));
      await tester.pump();

      expect(answer?['order'], 2);
      expect(answer?['selectedAnswer'], 'a');
    });

    testWidgets('matching step completes after all pairs are matched',
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

      await tester.tap(find.text('犬'));
      await tester.pump();
      await tester.tap(find.text('개'));
      await tester.pump();

      await tester.tap(find.text('猫'));
      await tester.pump();
      await tester.tap(find.text('고양이'));
      await tester.pump(const Duration(milliseconds: 501));

      expect(completed, isTrue);
    });

    testWidgets('sentence reorder step submits selected token order',
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
              totalSteps: 8,
              vocabItems: const [
                VocabItemModel(
                  id: 'vocab-1',
                  word: '先生',
                  reading: 'せんせい',
                  meaningKo: '선생님',
                  partOfSpeech: 'noun',
                ),
              ],
              onAnswer: (value) => answer = value,
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
      await tester.tap(find.text('확인'));
      await tester.pump(const Duration(milliseconds: 301));

      expect(answer?['order'], 5);
      expect(answer?['submittedOrder'], ['私は', '学生', 'です']);
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
              totalSteps: 8,
              vocabItems: const [],
              onAnswer: (_) {},
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('answer-empty-line')), findsOneWidget);
      expect(find.byKey(const ValueKey('answer-placeholder-0')), findsNothing);
      expect(find.byKey(const ValueKey('answer-placeholder-1')), findsNothing);
      expect(find.byKey(const ValueKey('answer-placeholder-2')), findsNothing);
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
              totalSteps: 8,
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

      await tester.tap(find.text('私は'));
      await tester.pump();

      expect(find.text('선택 1/3'), findsOneWidget);

      await tester.tap(find.text('です'));
      await tester.pump();
      await tester.tap(find.text('私は'));
      await tester.pump();
      await tester.tap(find.text('확인'));
      await tester.pump(const Duration(milliseconds: 301));

      expect(answer?['submittedOrder'], ['学生', 'です', '私は']);
    });
  });
}
