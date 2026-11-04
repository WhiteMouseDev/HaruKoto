import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/network/api_exception.dart';
import 'package:harukoto_mobile/core/providers/dio_provider.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';

void main() {
  testWidgets(
      'default container exposes catalogue failure once until explicit retry',
      (tester) async {
    final requests = <RequestOptions>[];
    final dio = Dio(BaseOptions(baseUrl: 'https://fixture.invalid/api/v1'));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      if (requests.length == 1) {
        handler.reject(DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          error:
              const ApiException(message: 'synthetic failure', statusCode: 503),
          response: Response<Map<String, dynamic>>(
              requestOptions: options, statusCode: 503),
        ));
      } else {
        handler.resolve(Response<Map<String, dynamic>>(
          requestOptions: options,
          statusCode: 200,
          data: {'chapters': <Object>[]},
        ));
      }
    }));
    // Deliberately leave the app's default retry policy in place. Only the
    // catalogue provider must opt out; a global test override hides regressions.
    final container = ProviderContainer(overrides: [
      currentAccountIdProvider.overrideWithValue('test-account'),
      currentAccountReaderProvider.overrideWithValue(() => 'test-account'),
      dioProvider.overrideWithValue(dio),
    ]);
    final subscription = container.listen(chaptersProvider('N5'), (_, __) {});
    addTearDown(() {
      subscription.close();
      container.dispose();
      dio.close(force: true);
    });
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    final failure = container.read(chaptersProvider('N5'));
    expect(failure.hasError, isTrue);
    expect(failure.isLoading, isFalse);
    expect(failure.error, isA<DioException>());
    expect(requests, hasLength(1));

    await tester.pump(const Duration(seconds: 10));
    expect(requests, hasLength(1));
    expect(container.read(chaptersProvider('N5')).isLoading, isFalse);
    expect(container.read(chaptersProvider('N5')).hasError, isTrue);

    container.invalidate(chaptersProvider('N5'));
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 1));
    }
    expect(
        container.read(chaptersProvider('N5')).requireValue.chapters, isEmpty);
    expect(requests, hasLength(2));
    expect(
        requests.every((request) =>
            request.method == 'GET' &&
            request.path == '/lessons/chapters' &&
            request.queryParameters['jlptLevel'] == 'N5'),
        isTrue);
  });
}
