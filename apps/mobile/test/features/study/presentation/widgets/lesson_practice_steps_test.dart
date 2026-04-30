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
      await tester.pump(const Duration(milliseconds: 801));

      expect(answer?['order'], 2);
      expect(answer?['selectedAnswer'], 'b');
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
  });
}
