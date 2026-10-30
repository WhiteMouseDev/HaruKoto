import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/stats/data/stats_repository.dart';

void main() {
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
