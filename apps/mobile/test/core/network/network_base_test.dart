import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/network/api_exception.dart';
import 'package:harukoto_mobile/core/network/network_base.dart';

void main() {
  group('AppErrorInterceptor', () {
    test('quiz connection timeout exposes Korean retry guidance', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid/api/v1'));
      addTearDown(dio.close);
      dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.connectionTimeout,
            message: 'The request connection took longer than 0:00:10.000000 '
                'and it was aborted. To get rid of this exception, try raising '
                'the RequestOptions.connectTimeout above the duration.',
          ),
          true,
        );
      }));
      dio.interceptors.add(AppErrorInterceptor());

      await expectLater(
        dio.post<dynamic>('/quiz/wrong-answer-review/start'),
        throwsA(isA<DioException>()
            .having((e) => e.type, 'type', DioExceptionType.connectionTimeout)
            .having(
              (e) => e.error,
              'safe error',
              isA<ApiException>()
                  .having(
                    (e) => e.userMessage,
                    'user message',
                    '서버 응답이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.',
                  )
                  .having(
                    (e) => e.requestPath,
                    'request path',
                    '/quiz/wrong-answer-review/start',
                  ),
            )),
      );
    });
  });

  group('redactDioLogMessage', () {
    test('redacts authorization and sensitive header values', () {
      final message = redactDioLogMessage('''
headers:
 Authorization: Bearer secret.jwt.token
 apikey: public-but-still-sensitive
 x-api-key: abc123
 Cookie: session=value
content-type: application/json
''');

      expect(message, contains('Authorization: <redacted>'));
      expect(message, contains('apikey: <redacted>'));
      expect(message, contains('x-api-key: <redacted>'));
      expect(message, contains('Cookie: <redacted>'));
      expect(message, contains('content-type: application/json'));
      expect(message, isNot(contains('secret.jwt.token')));
      expect(message, isNot(contains('public-but-still-sensitive')));
      expect(message, isNot(contains('abc123')));
      expect(message, isNot(contains('session=value')));
    });

    test('redacts token query parameters without changing safe parameters', () {
      final message = redactDioLogMessage(
        '/callback?access_token=secret&refresh_token=refresh&id_token=id&lesson=HN4-011',
      );

      expect(
        message,
        equals(
            '/callback?access_token=<redacted>&refresh_token=<redacted>&id_token=<redacted>&lesson=HN4-011'),
      );
    });
  });
}
