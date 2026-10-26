import 'package:flutter/material.dart';

import 'quiz_page.dart';

class QuizLaunchRequest {
  const QuizLaunchRequest({
    required this.quizType,
    required this.jlptLevel,
    required this.count,
    this.mode,
    this.resumeSessionId,
    this.stageId,
    this.sourceSessionId,
  });

  final String quizType;
  final String jlptLevel;
  final int count;
  final String? mode;
  final String? resumeSessionId;
  final String? stageId;
  final String? sourceSessionId;
}

typedef QuizRouteBuilder = Route<void> Function(QuizLaunchRequest request);

Route<void> buildQuizPageRoute(QuizLaunchRequest request) {
  return quizRoute(
    QuizPage(
      quizType: request.quizType,
      jlptLevel: request.jlptLevel,
      count: request.count,
      mode: request.mode,
      resumeSessionId: request.resumeSessionId,
      stageId: request.stageId,
      sourceSessionId: request.sourceSessionId,
    ),
  );
}

Future<void> openQuizPage(
  BuildContext context, {
  required QuizLaunchRequest request,
  bool replace = false,
  QuizRouteBuilder routeBuilder = buildQuizPageRoute,
}) {
  final navigator = Navigator.of(context, rootNavigator: true);
  final route = routeBuilder(request);
  if (replace) {
    return navigator.pushReplacement<void, void>(route);
  }
  return navigator.push<void>(route);
}

Future<void> openQuizPageForSession(
  BuildContext context, {
  required String quizType,
  required String jlptLevel,
  required int count,
  String? mode,
  String? resumeSessionId,
  String? stageId,
  bool replace = false,
  QuizRouteBuilder routeBuilder = buildQuizPageRoute,
}) {
  return openQuizPage(
    context,
    request: QuizLaunchRequest(
      quizType: quizType,
      jlptLevel: jlptLevel,
      count: count,
      mode: mode,
      resumeSessionId: resumeSessionId,
      stageId: stageId,
    ),
    replace: replace,
    routeBuilder: routeBuilder,
  );
}

Future<void> openReviewQuiz(
  BuildContext context, {
  required String quizType,
  required String jlptLevel,
  bool replace = false,
  QuizRouteBuilder routeBuilder = buildQuizPageRoute,
}) {
  return openQuizPageForSession(
    context,
    quizType: quizType,
    jlptLevel: jlptLevel,
    count: 10,
    mode: 'review',
    replace: replace,
    routeBuilder: routeBuilder,
  );
}

Future<void> openWrongAnswerReview(
  BuildContext context, {
  required String sourceSessionId,
  required String quizType,
  required String jlptLevel,
  bool replace = false,
  QuizRouteBuilder routeBuilder = buildQuizPageRoute,
}) {
  return openQuizPage(
    context,
    request: QuizLaunchRequest(
      quizType: quizType,
      jlptLevel: jlptLevel,
      count: 0,
      mode: 'wrong_answer_review',
      sourceSessionId: sourceSessionId,
    ),
    replace: replace,
    routeBuilder: routeBuilder,
  );
}
