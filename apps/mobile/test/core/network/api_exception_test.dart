import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/network/api_exception.dart';

void main() {
  group('ApiException', () {
    test('fromResponse parses detail from response data', () {
      final exception = ApiException.fromResponse(
        400,
        {'detail': '잘못된 요청입니다', 'errorCode': 'INVALID_INPUT'},
        requestPath: '/api/v1/quiz/start',
      );

      expect(exception.message, equals('잘못된 요청입니다'));
      expect(exception.statusCode, equals(400));
      expect(exception.errorCode, equals('INVALID_INPUT'));
      expect(exception.requestPath, equals('/api/v1/quiz/start'));
    });

    test('fromResponse uses default message when no detail', () {
      final exception = ApiException.fromResponse(500, null);
      expect(exception.message, equals('알 수 없는 오류가 발생했습니다.'));
    });

    test('fromResponse handles non-map data', () {
      final exception = ApiException.fromResponse(500, 'string error');
      expect(exception.message, equals('알 수 없는 오류가 발생했습니다.'));
    });

    test('fromResponse handles FastAPI validation detail list', () {
      final exception = ApiException.fromResponse(
        422,
        {
          'detail': [
            {
              'type': 'int_parsing',
              'loc': ['body', 'dailyGoal'],
              'msg': 'Input should be a valid integer',
            }
          ],
        },
      );
      expect(exception.message, equals('Input should be a valid integer'));
    });

    test('fromResponse handles detail list of strings', () {
      final exception = ApiException.fromResponse(
        422,
        {
          'detail': ['invalid payload'],
        },
      );
      expect(exception.message, equals('invalid payload'));
    });

    group('fromDioException', () {
      const transportMessages = {
        DioExceptionType.connectionTimeout: '서버 응답이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.',
        DioExceptionType.sendTimeout: '서버 응답이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.',
        DioExceptionType.receiveTimeout: '서버 응답이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.',
        DioExceptionType.connectionError: '네트워크 연결을 확인한 뒤 다시 시도해 주세요.',
        DioExceptionType.badCertificate: '서버에 안전하게 연결하지 못했어요. 잠시 후 다시 시도해 주세요.',
        DioExceptionType.cancel: '요청이 취소되었어요. 다시 시도해 주세요.',
        DioExceptionType.badResponse: '네트워크 연결을 확인한 뒤 다시 시도해 주세요.',
        DioExceptionType.unknown: '네트워크 연결을 확인한 뒤 다시 시도해 주세요.',
      };

      for (final type in DioExceptionType.values) {
        test('$type hides transport diagnostics from userMessage', () {
          const diagnostic =
              'DioException: RequestOptions.connectTimeout exceeded; SocketException';
          final exception = ApiException.fromDioException(DioException(
            requestOptions:
                RequestOptions(path: '/quiz/wrong-answer-review/start'),
            type: type,
            message: diagnostic,
          ));

          expect(exception.userMessage, transportMessages[type]);
          expect(exception.userMessage, isNot(contains('DioException')));
          expect(exception.userMessage, isNot(contains('RequestOptions')));
          expect(exception.userMessage, isNot(contains('SocketException')));
          expect(exception.message, diagnostic);
          expect(exception.requestPath, '/quiz/wrong-answer-review/start');
          expect(exception.statusCode, isNull);
        });
      }

      test('keeps the original mapped error when a retry wraps it again', () {
        final request = RequestOptions(path: '/quiz/wrong-answer-review/start');
        final mapped = ApiException.fromDioException(DioException(
          requestOptions: request,
          type: DioExceptionType.connectionTimeout,
          message: 'RequestOptions.connectTimeout exceeded',
        ));
        final exception = ApiException.fromDioException(DioException(
          requestOptions: request,
          type: DioExceptionType.connectionTimeout,
          error: mapped,
        ));

        expect(exception, same(mapped));
        expect(exception.message, 'RequestOptions.connectTimeout exceeded');
        expect(exception.userMessage, '서버 응답이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.');
      });

      test('missing transport diagnostics still uses safe connection guidance',
          () {
        final exception = ApiException.fromDioException(DioException(
          requestOptions: RequestOptions(path: '/quiz/start'),
          type: DioExceptionType.connectionError,
        ));

        expect(exception.userMessage, '네트워크 연결을 확인한 뒤 다시 시도해 주세요.');
      });

      test('preserves the structured server envelope and Korean message', () {
        final request = RequestOptions(path: '/quiz/wrong-answer-review/start');
        final exception = ApiException.fromDioException(DioException(
          requestOptions: request,
          type: DioExceptionType.badResponse,
          message: 'DioException: bad response diagnostics',
          response: Response<Map<String, dynamic>>(
            requestOptions: request,
            statusCode: 409,
            data: {
              'error': {
                'code': 'SYSTEM_ERROR',
                'message': '이번 퀴즈에서 복습할 오답이 없습니다',
                'details': {'reason': 'no_wrong_answers'},
              },
            },
          ),
        ));

        expect(exception.message, '이번 퀴즈에서 복습할 오답이 없습니다');
        expect(exception.errorCode, 'SYSTEM_ERROR');
        expect(exception.details, {'reason': 'no_wrong_answers'});
        expect(exception.statusCode, 409);
        expect(exception.requestPath, '/quiz/wrong-answer-review/start');
        expect(exception.userMessage, '이미 처리된 요청입니다.');
      });

      test('preserves server Korean guidance for an unmapped HTTP status', () {
        final request = RequestOptions(path: '/quiz/start');
        final exception = ApiException.fromDioException(DioException(
          requestOptions: request,
          type: DioExceptionType.badResponse,
          response: Response<Map<String, dynamic>>(
            requestOptions: request,
            statusCode: 423,
            data: {'detail': '잠시 후 다시 학습을 시작해 주세요.'},
          ),
        ));

        expect(exception.userMessage, '잠시 후 다시 학습을 시작해 주세요.');
      });
    });

    group('userMessage', () {
      test('returns correct message for 400', () {
        const e = ApiException(message: 'raw', statusCode: 400);
        expect(e.userMessage, equals('잘못된 요청입니다.'));
      });

      test('returns correct message for 401', () {
        const e = ApiException(message: 'raw', statusCode: 401);
        expect(e.userMessage, equals('로그인이 필요합니다.'));
      });

      test('returns correct message for 403', () {
        const e = ApiException(message: 'raw', statusCode: 403);
        expect(e.userMessage, equals('접근 권한이 없습니다.'));
      });

      test('returns correct message for 404', () {
        const e = ApiException(message: 'raw', statusCode: 404);
        expect(e.userMessage, equals('요청한 데이터를 찾을 수 없습니다.'));
      });

      test('returns correct message for 409', () {
        const e = ApiException(message: 'raw', statusCode: 409);
        expect(e.userMessage, equals('이미 처리된 요청입니다.'));
      });

      test('returns correct message for 429', () {
        const e = ApiException(message: 'raw', statusCode: 429);
        expect(e.userMessage, equals('요청이 너무 많습니다. 잠시 후 다시 시도해주세요.'));
      });

      test('returns server error message for 5xx', () {
        const e = ApiException(message: 'raw', statusCode: 502);
        expect(e.userMessage, equals('서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.'));
      });

      test('returns raw message for unknown status code', () {
        const e = ApiException(message: 'custom error', statusCode: 418);
        expect(e.userMessage, equals('custom error'));
      });

      test('returns raw message when no status code', () {
        const e = ApiException(message: 'network error');
        expect(e.userMessage, equals('network error'));
      });
    });

    test('toString includes status code and message', () {
      const e = ApiException(message: 'test', statusCode: 404);
      expect(e.toString(), equals('ApiException(404): test'));
    });
  });
}
