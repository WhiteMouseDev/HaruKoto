import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/network/network_base.dart';

void main() {
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
