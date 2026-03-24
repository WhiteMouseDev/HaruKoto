import 'package:flutter/material.dart';

import 'quiz_page.dart';

void openQuizPageForSession(
  BuildContext context, {
  required String quizType,
  required String jlptLevel,
  required int count,
  String? mode,
  String? resumeSessionId,
  String? stageId,
}) {
  Navigator.of(context, rootNavigator: true).push(
    quizRoute(
      QuizPage(
        quizType: quizType,
        jlptLevel: jlptLevel,
        count: count,
        mode: mode,
        resumeSessionId: resumeSessionId,
        stageId: stageId,
      ),
    ),
  );
}

void openReviewQuiz(
  BuildContext context, {
  required String quizType,
  required String jlptLevel,
}) {
  openQuizPageForSession(
    context,
    quizType: quizType,
    jlptLevel: jlptLevel,
    count: 10,
    mode: 'review',
  );
}
