import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/stats/data/stats_repository.dart';

void main() {
  test('study overview loads seven saved-answer days and preserves failures',
      () async {
    final dio = Dio();
    addTearDown(dio.close);
    final daily = [
      for (var day = 1; day <= 7; day++)
        {
          'date': '2026-11-0$day',
          'hasStudied': day == 2,
          'vocabularyAnsweredCount': day == 2 ? 3 : 0,
          'grammarAnsweredCount': day == 2 ? 2 : 0,
          'sentenceArrangeAnsweredCount': day == 2 ? 1 : 0,
        },
    ];
    var responseState = 'valid';
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      expect(options.method, 'GET');
      expect(options.path, '/stats/study-overview');
      if (responseState == 'offline') {
        handler.reject(DioException(requestOptions: options));
        return;
      }
      handler.resolve(Response(requestOptions: options, data: {
        'quizzesCompleted': 12,
        'correctAnswers': 9,
        'totalAnswers': 20,
        'conversationCount': 3,
        'daily': responseState == 'valid' ? daily : daily.take(6).toList(),
      }));
    }));
    final repository = StatsRepository(dio);
    final overview = await repository.fetchStudyOverview();
    expect(overview.quizzesCompleted, 12);
    expect(overview.correctAnswers, 9);
    expect(overview.totalAnswers, 20);
    expect(overview.conversationCount, 3);
    expect(overview.daily, hasLength(7));
    expect(overview.daily[1].sentenceArrangeAnsweredCount, 1);

    responseState = 'invalid';
    await expectLater(repository.fetchStudyOverview(), throwsFormatException);
    responseState = 'offline';
    await expectLater(
        repository.fetchStudyOverview(), throwsA(isA<DioException>()));
  });

  test('JLPT progress opts in to totals for every content-bearing level',
      () async {
    final dio = Dio();
    addTearDown(dio.close);
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      expect(options.method, 'GET');
      expect(options.path, '/stats/jlpt-progress');
      expect(options.queryParameters, {'include_all_levels': true});
      handler.resolve(Response(requestOptions: options, data: {
        'levels': [
          {
            'level': 'N3',
            'vocabulary': {'total': 350, 'mastered': 0, 'inProgress': 0},
            'grammar': {'total': 60, 'mastered': 0, 'inProgress': 0},
          },
        ],
      }));
    }));
    final progress = await StatsRepository(dio).fetchJlptProgress();
    expect(progress.levels.single.level, 'N3');
    expect(progress.levels.single.vocabulary.total, 350);
    expect(progress.levels.single.grammar.mastered, 0);
  });

  test('JLPT progress distinguishes missing data from no content', () async {
    final dio = Dio();
    addTearDown(dio.close);
    var body = <String, dynamic>{};
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      handler.resolve(Response(requestOptions: options, data: body));
    }));
    final repository = StatsRepository(dio);

    await expectLater(repository.fetchJlptProgress(), throwsFormatException);
    body = {'levels': []};
    expect((await repository.fetchJlptProgress()).levels, isEmpty);
  });

  test('month requests only visible month and failure is not empty history',
      () async {
    final dio = Dio();
    addTearDown(dio.close);
    final requests = <Map<String, dynamic>>[];
    var fails = true;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options.queryParameters);
      if (fails) {
        handler.reject(DioException(
            requestOptions: options, type: DioExceptionType.connectionError));
      } else {
        handler.resolve(Response(requestOptions: options, data: {
          'records': [
            {'date': '2026-09-29', 'hasStudied': true}
          ]
        }));
      }
    }));
    final repository = StatsRepository(dio);
    await expectLater(
        repository.fetchMonthHistory(2026, 9), throwsA(isA<DioException>()));
    expect(requests, [
      {'year': 2026, 'month': 9}
    ]);
    fails = false;
    final records = await repository.fetchMonthHistory(2026, 9);
    expect(records.single.hasStudyActivity, isTrue);
  });

  test('year history includes new KST month and propagates a failed month',
      () async {
    final dio = Dio();
    addTearDown(dio.close);
    final months = <int>[];
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      final month = options.queryParameters['month'] as int;
      months.add(month);
      if (month == 2) {
        handler.reject(DioException(requestOptions: options));
      } else {
        handler
            .resolve(Response(requestOptions: options, data: {'records': []}));
      }
    }));
    final repository =
        StatsRepository(dio, now: () => DateTime.utc(2026, 1, 31, 15));
    await expectLater(
        repository.fetchHistory(2026), throwsA(isA<DioException>()));
    expect(months, [1, 2]);
  });
}
