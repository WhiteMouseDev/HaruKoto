import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/network/api_exception.dart';
import 'package:harukoto_mobile/features/study/data/study_repository.dart';

void main() {
  for (final answeredIds in [
    <String>[],
    ['wrong-1']
  ]) {
    test('session wrong review consumes resume shape ($answeredIds)', () async {
      final requests = <RequestOptions>[];
      final dio = _fakeDio(requests, response: {
        'sessionId': 'child-session',
        'questions': [_question('wrong-1'), _question('wrong-2')],
        'answeredQuestionIds': answeredIds,
        'totalQuestions': 2,
        'correctCount': answeredIds.length,
        'quizType': 'GRAMMAR',
      });
      addTearDown(dio.close);

      final result = await ApiStudyRepository(dio)
          .startWrongAnswerReview('source-session');
      expect(requests, hasLength(1));
      expect(requests.single.method, 'POST');
      expect(requests.single.path, '/quiz/wrong-answer-review/start');
      expect(requests.single.data, {'sourceSessionId': 'source-session'});
      expect(result.sessionId, 'child-session');
      expect(result.questions.map((q) => q.questionId), ['wrong-1', 'wrong-2']);
      expect(result.answeredQuestionIds, answeredIds);
      expect(result.correctCount, answeredIds.length);
      expect(result.quizType, 'GRAMMAR');
    });
  }

  for (final error in [
    (400, '이 퀴즈 유형은 이번 오답 복습을 지원하지 않습니다'),
    (409, '이번 퀴즈에서 복습할 오답이 없습니다'),
    (409, '기존 퀴즈 기록을 안전하게 복원할 수 없습니다'),
    (409, '완료한 퀴즈에서만 오답 복습을 시작할 수 있습니다'),
    (409, '복습할 학습 항목을 찾을 수 없습니다'),
  ]) {
    test('wrong-review error keeps safe endpoint context: ${error.$2}',
        () async {
      final requests = <RequestOptions>[];
      final dio =
          _fakeDio(requests, status: error.$1, response: {'detail': error.$2});
      addTearDown(dio.close);
      await expectLater(
        ApiStudyRepository(dio).startWrongAnswerReview('same-source'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'status', error.$1)
            .having((e) => e.userMessage, 'message', error.$2)),
      );
      expect(requests.map((r) => r.path), ['/quiz/wrong-answer-review/start']);
      expect(
        const ApiException(message: 'other endpoint', statusCode: 409)
            .userMessage,
        '이미 처리된 요청입니다.',
      );
    });
  }

  test('unknown source errors do not display internal details', () async {
    final dio = _fakeDio([],
        status: 409, response: {'detail': 'synthetic internal diagnostic'});
    addTearDown(dio.close);
    await expectLater(
      ApiStudyRepository(dio).startWrongAnswerReview('same-source'),
      throwsA(isA<ApiException>().having(
        (e) => e.userMessage,
        'safe message',
        '이번 퀴즈의 오답 복습을 시작하지 못했어요. 학습으로 돌아가 다시 확인해 주세요.',
      )),
    );
  });

  test('real error envelope preserves no-wrong-answer guidance', () async {
    final dio = _fakeDio([],
        status: 409,
        response: {
          'error': {
            'code': 'SYSTEM_ERROR',
            'message': '이번 퀴즈에서 복습할 오답이 없습니다',
            'details': null,
          }
        });
    addTearDown(dio.close);
    await expectLater(
      ApiStudyRepository(dio).startWrongAnswerReview('same-source'),
      throwsA(isA<ApiException>()
          .having((e) => e.userMessage, 'message', '이번 퀴즈에서 복습할 오답이 없습니다')
          .having((e) => e.errorCode, 'code', 'SYSTEM_ERROR')),
    );
  });

  test('session wrong list parses a grammar display fallback', () async {
    final requests = <RequestOptions>[];
    final dio = _fakeDio(requests, response: {
      'wrongAnswers': [
        {'questionId': 'grammar-1', 'word': '〜は〜です', 'meaningKo': '~는 ~입니다'}
      ]
    });
    addTearDown(dio.close);
    final result = await ApiStudyRepository(dio)
        .fetchWrongAnswersBySession('grammar-source');
    expect(requests.single.queryParameters, {'session_id': 'grammar-source'});
    expect(result.single.word, '〜は〜です');
    expect(result.single.meaningKo, '~는 ~입니다');
  });

  test('malformed nullable wrong list is an error instead of a fake empty list',
      () async {
    final dio = _fakeDio([], response: {
      'wrongAnswers': [
        {'questionId': 'broken', 'word': null, 'meaningKo': null}
      ]
    });
    addTearDown(dio.close);
    await expectLater(
      ApiStudyRepository(dio).fetchWrongAnswersBySession('same-source'),
      throwsA(isA<TypeError>()),
    );
  });
}

Dio _fakeDio(
  List<RequestOptions> requests, {
  required Map<String, dynamic> response,
  int status = 200,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api/v1'));
  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
    requests.add(options);
    final result = Response<Map<String, dynamic>>(
      requestOptions: options,
      data: response,
      statusCode: status,
    );
    if (status == 200) {
      handler.resolve(result);
    } else {
      handler.reject(DioException(
        requestOptions: options,
        response: result,
        type: DioExceptionType.badResponse,
        error: ApiException.fromResponse(status, response),
      ));
    }
  }));
  return dio;
}

Map<String, dynamic> _question(String id) => {
      'questionId': id,
      'questionText': '〜は〜です',
      'options': [
        {'id': 'right', 'text': '~는 ~입니다'},
        {'id': 'wrong', 'text': '그리고'},
      ],
      'correctOptionId': 'right',
    };
