import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/study_repository.dart';

void main() {
  test(
      'matching preserves question and correct-option IDs through answer and result',
      () async {
    final dio = Dio();
    addTearDown(dio.close);
    final requests = <RequestOptions>[];
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      final data = switch (options.path) {
        '/quiz/start' => {
            'sessionId': 'session',
            'totalQuestions': 1,
            'questions': [
              {
                'questionId': 'vocabulary-id',
                'questionText': '猫',
                'questionSubText': 'ねこ',
                'options': <Object>[],
                'correctOptionId': 'pair-option-id',
              }
            ],
            'matchingPairs': [
              {'id': 'other-pair', 'word': '犬', 'meaning': '개'},
              {'id': 'pair-option-id', 'word': '猫', 'meaning': '고양이'}
            ],
          },
        '/quiz/answer' => {'success': true},
        '/quiz/complete' => {
            'sessionId': 'session',
            'correctCount': 1,
            'totalQuestions': 1,
            'accuracy': 100.0,
            'xpEarned': 10,
            'level': 1,
            'currentXp': 10,
            'xpForNext': 100,
            'events': <Object>[],
          },
        _ => throw StateError('Unexpected request'),
      };
      handler.resolve(Response(requestOptions: options, data: data));
    }));
    final repository = ApiStudyRepository(dio);
    final session = await repository.startQuiz(
        quizType: 'VOCABULARY', jlptLevel: 'N5', count: 1, mode: 'matching');
    final question = session.questions.single;
    expect(question.questionId, 'vocabulary-id');
    expect(question.correctOptionId, 'pair-option-id');
    expect(question.matchingWord, '猫');
    expect(question.matchingMeaning, '고양이');
    expect(question.questionSubText, 'ねこ');
    await repository.answerQuestion(
        sessionId: session.sessionId,
        questionId: question.questionId,
        selectedOptionId: question.correctOptionId,
        isCorrect: true,
        timeSpentSeconds: 2,
        questionType: 'VOCABULARY');
    expect(requests[1].data, {
      'sessionId': 'session',
      'questionId': 'vocabulary-id',
      'selectedOptionId': 'pair-option-id',
      'isCorrect': true,
      'timeSpentSeconds': 2,
      'questionType': 'VOCABULARY',
    });
    final result = await repository.completeQuiz(session.sessionId);
    expect(result.correctCount, 1);
    expect(result.accuracy, 100);
    expect(result.xpEarned, 10);
  });
}
