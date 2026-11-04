import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_result_feedback.dart';

void main() {
  group('lessonResultAnswerText', () {
    const question = LessonQuestionModel(
      order: 2,
      type: 'VOCAB_MCQ',
      prompt: '「学生」の 뜻은?',
      options: [
        QuizOptionModel(id: 'b', text: '선생님'),
        QuizOptionModel(id: 'a', text: '학생'),
      ],
      // Detail answer keys are not authoritative for a submitted result.
      correctAnswer: 'b',
    );
    test(
        'maps the submitted option ID, independent of option order or detail key',
        () {
      expect(
          lessonResultAnswerText(
            const QuestionResultModel(
                order: 2, isCorrect: false, correctAnswer: 'a'),
            question,
          ),
          '학생');
    });
    test('does not guess missing/unknown answer keys or mismatched questions',
        () {
      for (final answer in [null, '', 'unknown']) {
        expect(
            lessonResultAnswerText(
              QuestionResultModel(
                  order: 2, isCorrect: false, correctAnswer: answer),
              question,
            ),
            isNull);
      }
      const result =
          QuestionResultModel(order: 3, isCorrect: false, correctAnswer: 'a');
      expect(lessonResultAnswerText(result, question), isNull);
      expect(lessonResultAnswerText(result, null), isNull);
    });
    test('duplicate option IDs and blank option text are unavailable', () {
      for (final options in [
        const [
          QuizOptionModel(id: 'a', text: '학생'),
          QuizOptionModel(id: 'a', text: '선생님')
        ],
        const [QuizOptionModel(id: 'a', text: ' ')],
      ]) {
        expect(
            lessonResultAnswerText(
              const QuestionResultModel(
                  order: 2, isCorrect: false, correctAnswer: 'a'),
              LessonQuestionModel(
                  order: 2, type: 'VOCAB_MCQ', prompt: '문제', options: options),
            ),
            isNull);
      }
    });
    test('cloze shows the selected answer text without inventing a sentence',
        () {
      expect(
          lessonResultAnswerText(
            const QuestionResultModel(
                order: 1, isCorrect: false, correctAnswer: 'p'),
            const LessonQuestionModel(
                order: 1,
                type: 'CONTEXT_CLOZE',
                prompt: '빈칸을 채우세요',
                options: [QuizOptionModel(id: 'p', text: 'は')]),
          ),
          'は');
    });
    test('reorder joins the authoritative token sequence and keeps duplicates',
        () {
      const tokens = ['母', 'は', '「は」', 'を', '書きます'];
      expect(
          lessonResultAnswerText(
            const QuestionResultModel(
                order: 1, isCorrect: false, correctOrder: tokens),
            const LessonQuestionModel(
                order: 1,
                type: 'SENTENCE_REORDER',
                prompt: '문장을 완성하세요',
                tokens: ['書きます', 'を', '「は」', 'は', '母']),
          ),
          '母は「は」を書きます');
      expect(
          lessonResultAnswerText(
            const QuestionResultModel(
                order: 1, isCorrect: false, correctOrder: ['は', 'は']),
            const LessonQuestionModel(
                order: 1, type: 'SENTENCE_REORDER', prompt: '중복 토큰'),
          ),
          'はは');
    });
    test('missing/empty reorder and unsupported types are unavailable', () {
      for (final order in [
        null,
        <String>[],
        ['私', ' ']
      ]) {
        expect(
            lessonResultAnswerText(
              QuestionResultModel(
                  order: 1, isCorrect: false, correctOrder: order),
              const LessonQuestionModel(
                  order: 1, type: 'SENTENCE_REORDER', prompt: '문제'),
            ),
            isNull);
      }
      expect(
          lessonResultAnswerText(
            const QuestionResultModel(
                order: 1, isCorrect: false, correctAnswer: 'a'),
            const LessonQuestionModel(
                order: 1,
                type: 'LEGACY',
                prompt: '문제',
                options: [QuizOptionModel(id: 'a', text: '학생')]),
          ),
          isNull);
    });
  });

  group('lessonResultReviewDate', () {
    test('uses fixed Korea time across UTC year boundary, independent of today',
        () {
      expect(lessonResultReviewDate('2020-12-31T15:01:02Z'),
          '2021년 1월 1일 00:01 (한국 시간)');
      expect(lessonResultReviewDate('2030-12-31T15:01:02.123456+00:00'),
          '2031년 1월 1일 00:01 (한국 시간)');
    });
    test('resolves equivalent offset representations to the same instant', () {
      for (final date in [
        '2026-11-03T00:00:00Z',
        '2026-11-03T09:00:00+09:00',
        '2026-11-03T09:00:00+0900',
        '2026-11-02T19:00:00-05:00'
      ]) {
        expect(lessonResultReviewDate(date), '2026년 11월 3일 09:00 (한국 시간)');
      }
    });
    test(
        'accepts leap days but rejects normalizing invalid calendar/time values',
        () {
      expect(lessonResultReviewDate('2024-02-29T00:00:00Z'),
          '2024년 2월 29일 09:00 (한국 시간)');
      for (final date in [
        null,
        '',
        'invalid',
        '2026-11-03',
        '2026-11-03T12:00:00',
        '2026-02-29T00:00:00Z',
        '2026-13-01T00:00:00Z',
        '2026-11-31T00:00:00Z',
        '2026-11-03T24:00:00Z',
        '2026-11-03T00:60:00Z',
        '2026-11-03T00:00:60Z',
        '2026-11-03T00:00:00+99:99',
        '2026-11-03T00:00:00+09:99',
        '0000-01-01T00:00:00Z'
      ]) {
        expect(lessonResultReviewDate(date), isNull,
            reason: '$date must not silently normalize');
      }
    });
  });
}
