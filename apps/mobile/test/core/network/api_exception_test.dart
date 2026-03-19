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
