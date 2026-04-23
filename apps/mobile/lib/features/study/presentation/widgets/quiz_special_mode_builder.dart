import 'package:flutter/material.dart';

import '../../data/models/quiz_question_model.dart';
import 'cloze_quiz.dart';
import 'matching_quiz.dart';
import 'sentence_arrange_quiz.dart';
import 'typing_quiz.dart';

typedef QuizSpecialAnswerHandler = void Function(
  String questionId,
  bool isCorrect,
  String questionType, {
  String? optionId,
});

class QuizSpecialModeBuilder {
  const QuizSpecialModeBuilder();

  Widget? build({
    required String resolvedMode,
    required List<QuizQuestionModel> questions,
    required String quizType,
    required bool showFurigana,
    required VoidCallback onComplete,
    required QuizSpecialAnswerHandler onSubmitSpecialAnswer,
  }) {
    return switch (resolvedMode) {
      'matching' => MatchingQuiz(
          questions: questions,
          showFurigana: showFurigana,
          onMatchResult: (questionId, isCorrect) {
            onSubmitSpecialAnswer(
              questionId,
              isCorrect,
              quizType,
            );
          },
          onComplete: onComplete,
        ),
      'cloze' => ClozeQuiz(
          questions: questions,
          onAnswer: (questionId, optionId, isCorrect) {
            onSubmitSpecialAnswer(
              questionId,
              isCorrect,
              'CLOZE',
              optionId: optionId,
            );
          },
          onComplete: onComplete,
        ),
      'arrange' => SentenceArrangeQuiz(
          questions: questions,
          onAnswer: (questionId, isCorrect) {
            onSubmitSpecialAnswer(
              questionId,
              isCorrect,
              'SENTENCE_ARRANGE',
            );
          },
          onComplete: onComplete,
        ),
      'typing' => TypingQuiz(
          questions: questions,
          onAnswer: (questionId, isCorrect) {
            onSubmitSpecialAnswer(
              questionId,
              isCorrect,
              'VOCABULARY',
            );
          },
          onComplete: onComplete,
        ),
      _ => null,
    };
  }
}
