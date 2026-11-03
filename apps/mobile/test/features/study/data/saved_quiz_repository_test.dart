import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/saved_quiz_model.dart';
import 'package:harukoto_mobile/features/study/data/study_repository.dart';

void main() {
  test('list contract uses optional filters, no correctness field, UTC date',
      () async {
    final dio = Dio();
    addTearDown(dio.close);
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      expect(options.path, '/quiz/incomplete-sessions');
      expect(options.queryParameters, {
        'limit': 20,
        'cursor': 'page-two',
        'quizType': 'VOCABULARY',
        'jlptLevel': 'N5',
      });
      handler.resolve(Response(requestOptions: options, data: {
        'sessions': [_summary()],
        'nextCursor': 'page-three',
      }));
    }));
    final page = await ApiStudyRepository(dio).fetchIncompleteQuizzes(
      cursor: 'page-two',
      quizType: 'VOCABULARY',
      jlptLevel: 'N5',
    );
    expect(page.sessions.single.canResume, isTrue);
    expect(page.sessions.single.startedLabel, '2026.10.31 시작');
    expect(page.nextCursor, 'page-three');
    expect(page.legacyFallback, isFalse);
  });

  test('only a first-page 404 falls back to the existing representative',
      () async {
    final paths = <String>[];
    final dio = Dio();
    addTearDown(dio.close);
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      paths.add(options.path);
      if (options.path.endsWith('incomplete-sessions')) {
        handler.reject(_httpError(options, 404));
      } else {
        handler.resolve(Response(requestOptions: options, data: {
          'session': {..._summary(), 'correctCount': 1},
        }));
      }
    }));
    final page = await ApiStudyRepository(dio).fetchIncompleteQuizzes();
    expect(paths, ['/quiz/incomplete-sessions', '/quiz/incomplete']);
    expect(page.sessions.single.id, 'saved');
    expect(page.legacyFallback, isTrue);
    expect(page.nextCursor, isNull);
  });

  for (final status in [401, 403, 500, 503]) {
    test('$status remains an error without fallback or quiz creation',
        () async {
      final paths = <String>[];
      final dio = Dio();
      addTearDown(dio.close);
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        paths.add(options.path);
        handler.reject(_httpError(options, status));
      }));
      await expectLater(ApiStudyRepository(dio).fetchIncompleteQuizzes(),
          throwsA(isA<DioException>()));
      expect(paths, ['/quiz/incomplete-sessions']);
    });
  }

  test('missing second-page endpoint never silently becomes the first page',
      () async {
    final dio = Dio();
    addTearDown(dio.close);
    var calls = 0;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      calls++;
      handler.reject(_httpError(options, 404));
    }));
    await expectLater(
      ApiStudyRepository(dio).fetchIncompleteQuizzes(cursor: 'next'),
      throwsA(isA<DioException>()),
    );
    expect(calls, 1);
  });

  test('invalid or future statuses never acquire a progress indicator', () {
    for (final status in ['invalid_snapshot', 'legacy_unavailable', 'future']) {
      final session = SavedQuizModel.fromJson({
        ..._summary(),
        'resumeStatus': status,
        'remainingCount': null,
      });
      expect(session.canResume, isFalse);
      expect(session.readyForResult, isFalse);
    }
    final complete = SavedQuizModel.fromJson({
      ..._summary(),
      'answeredCount': 10,
      'remainingCount': 0,
    });
    expect(complete.actionLabel, '결과 확인하기');
  });
}

Map<String, Object?> _summary() => {
      'id': 'saved',
      'quizType': 'VOCABULARY',
      'jlptLevel': 'N5',
      'mode': 'matching',
      'totalQuestions': 10,
      'answeredCount': 2,
      'remainingCount': 8,
      'startedAt': '2026-10-30T16:00:00Z',
      'resumeStatus': 'available',
      'resumeReason': null,
    };

DioException _httpError(RequestOptions options, int status) => DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response(requestOptions: options, statusCode: status),
    );
