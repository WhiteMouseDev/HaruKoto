import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_question_model.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/cloze_quiz.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/matching_quiz.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/quiz_special_mode_builder.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/sentence_arrange_quiz.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/typing_quiz.dart';

void main() {
  group('QuizSpecialModeBuilder', () {
    const builder = QuizSpecialModeBuilder();

    test('returns null for non-special modes', () {
      final child = builder.build(
        resolvedMode: 'standard',
        questions: const [_matchingQuestion],
        quizType: 'VOCABULARY',
        showFurigana: true,
        onComplete: () {},
        onSubmitSpecialAnswer: (_, __, ___, {optionId}) {},
      );

      expect(child, isNull);
    });

    test('builds matching quiz and preserves the requested quiz type', () {
      final capture = _SpecialAnswerCapture();
      var completed = false;

      final child = builder.build(
        resolvedMode: 'matching',
        questions: const [_matchingQuestion],
        quizType: 'GRAMMAR',
        showFurigana: false,
        onComplete: () {
          completed = true;
        },
        onSubmitSpecialAnswer: capture.call,
      );

      final quiz = child as MatchingQuiz;
      expect(quiz.showFurigana, isFalse);

      quiz.onMatchResult('q-match', true);
      quiz.onComplete();

      expect(capture.questionId, 'q-match');
      expect(capture.isCorrect, isTrue);
      expect(capture.questionType, 'GRAMMAR');
      expect(capture.optionId, isNull);
      expect(completed, isTrue);
    });

    test('builds cloze quiz and forwards the selected option id', () {
      final capture = _SpecialAnswerCapture();

      final child = builder.build(
        resolvedMode: 'cloze',
        questions: const [_clozeQuestion],
        quizType: 'VOCABULARY',
        showFurigana: true,
        onComplete: () {},
        onSubmitSpecialAnswer: capture.call,
      );

      final quiz = child as ClozeQuiz;
      quiz.onAnswer('q-cloze', 'o2', true);

      expect(capture.questionId, 'q-cloze');
      expect(capture.isCorrect, isTrue);
      expect(capture.questionType, 'CLOZE');
      expect(capture.optionId, 'o2');
    });

    test('builds sentence arrange quiz with its API question type', () {
      final capture = _SpecialAnswerCapture();

      final child = builder.build(
        resolvedMode: 'arrange',
        questions: const [_arrangeQuestion],
        quizType: 'VOCABULARY',
        showFurigana: true,
        onComplete: () {},
        onSubmitSpecialAnswer: capture.call,
      );

      final quiz = child as SentenceArrangeQuiz;
      quiz.onAnswer('q-arrange', false);

      expect(capture.questionId, 'q-arrange');
      expect(capture.isCorrect, isFalse);
      expect(capture.questionType, 'SENTENCE_ARRANGE');
      expect(capture.optionId, isNull);
    });

    test('builds typing quiz with vocabulary answer type', () {
      final capture = _SpecialAnswerCapture();

      final child = builder.build(
        resolvedMode: 'typing',
        questions: const [_typingQuestion],
        quizType: 'GRAMMAR',
        showFurigana: true,
        onComplete: () {},
        onSubmitSpecialAnswer: capture.call,
      );

      final quiz = child as TypingQuiz;
      quiz.onAnswer('q-typing', true);

      expect(capture.questionId, 'q-typing');
      expect(capture.isCorrect, isTrue);
      expect(capture.questionType, 'VOCABULARY');
      expect(capture.optionId, isNull);
    });
  });
}

class _SpecialAnswerCapture {
  String? questionId;
  bool? isCorrect;
  String? questionType;
  String? optionId;

  void call(
    String questionId,
    bool isCorrect,
    String questionType, {
    String? optionId,
  }) {
    this.questionId = questionId;
    this.isCorrect = isCorrect;
    this.questionType = questionType;
    this.optionId = optionId;
  }
}

const _matchingQuestion = QuizQuestionModel(
  questionId: 'q-match',
  questionText: 'ignored',
  options: [],
  correctOptionId: '',
  matchingWord: '食べる',
  matchingMeaning: '먹다',
);

const _clozeQuestion = QuizQuestionModel(
  questionId: 'q-cloze',
  questionText: '私は ____ を 食べます。',
  sentence: '私は {blank} を 食べます。',
  options: [
    QuizOption(id: 'o1', text: 'りんご'),
    QuizOption(id: 'o2', text: 'ごはん'),
  ],
  correctOptionId: 'o2',
);

const _arrangeQuestion = QuizQuestionModel(
  questionId: 'q-arrange',
  questionText: 'Arrange this',
  options: [],
  correctOptionId: '',
  tokens: ['食べ', 'ます'],
);

const _typingQuestion = QuizQuestionModel(
  questionId: 'q-typing',
  questionText: 'Type this',
  options: [],
  correctOptionId: '',
  prompt: '食べる',
  answer: 'taberu',
);
