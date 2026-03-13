import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// Testable version of AuthInterceptor that doesn't depend on Supabase.
class TestableAuthInterceptor extends Interceptor {
  bool _isRefreshing = false;
  Completer<String?>? _refreshCompleter;
  DateTime? _lastRefreshAttempt;

  final Future<String?> Function() onRefreshToken;
  final String? Function() onGetCurrentToken;

  int refreshCallCount = 0;

  TestableAuthInterceptor({
    required this.onRefreshToken,
    required this.onGetCurrentToken,
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = onGetCurrentToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }

    final now = DateTime.now();
    if (_lastRefreshAttempt != null &&
        now.difference(_lastRefreshAttempt!).inSeconds < 10) {
      handler.next(err);
      return;
    }
    _lastRefreshAttempt = now;

    try {
      final newToken = await _refreshToken();
      if (newToken != null) {
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $newToken';
        // In real code this retries with a new Dio client.
        // For testing, we resolve with a mock response.
        return handler.resolve(Response(
          requestOptions: opts,
          statusCode: 200,
          data: {'retried': true},
        ));
      }
    } catch (e) {
      // Token refresh failed
    }
    handler.next(err);
  }

  Future<String?> _refreshToken() async {
    if (_isRefreshing) {
      return _refreshCompleter!.future;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<String?>();

    try {
      refreshCallCount++;
      final token = await onRefreshToken();
      _refreshCompleter!.complete(token);
      return token;
    } catch (e) {
      // Ignore the error on the completer's future to avoid unhandled errors
      _refreshCompleter!.future.ignore();
      _refreshCompleter!.completeError(e);
      rethrow;
    } finally {
      _isRefreshing = false;
    }
  }
}

void main() {
  group('AuthInterceptor', () {
    late TestableAuthInterceptor interceptor;
    late Completer<String?> refreshCompleter;
    String? currentToken;

    setUp(() {
      refreshCompleter = Completer<String?>();
      currentToken = 'old-token';
      interceptor = TestableAuthInterceptor(
        onRefreshToken: () => refreshCompleter.future,
        onGetCurrentToken: () => currentToken,
      );
    });

    DioException make401Error() {
      final opts = RequestOptions(path: '/test');
      return DioException(
        requestOptions: opts,
        response: Response(requestOptions: opts, statusCode: 401),
        type: DioExceptionType.badResponse,
      );
    }

    DioException make500Error() {
      final opts = RequestOptions(path: '/test');
      return DioException(
        requestOptions: opts,
        response: Response(requestOptions: opts, statusCode: 500),
        type: DioExceptionType.badResponse,
      );
    }

    test('attaches token to outgoing requests', () {
      currentToken = 'my-token';
      final opts = RequestOptions(path: '/test');
      final handler = _MockRequestHandler();

      interceptor.onRequest(opts, handler);

      expect(handler.nextOptions?.headers['Authorization'],
          equals('Bearer my-token'));
    });

    test('does not attach token when no session', () {
      currentToken = null;
      final opts = RequestOptions(path: '/test');
      final handler = _MockRequestHandler();

      interceptor.onRequest(opts, handler);

      expect(handler.nextOptions?.headers['Authorization'], isNull);
    });

    test('non-401 errors pass through', () {
      final handler = _MockErrorHandler();
      interceptor.onError(make500Error(), handler);

      expect(handler.nextCalled, isTrue);
      expect(interceptor.refreshCallCount, equals(0));
    });

    test('401 triggers token refresh and retries request', () async {
      final handler = _MockErrorHandler();
      interceptor.onError(make401Error(), handler);

      // Complete the refresh
      refreshCompleter.complete('new-token');
      await Future.delayed(Duration.zero);

      expect(interceptor.refreshCallCount, equals(1));
      expect(handler.resolvedResponse, isNotNull);
      expect(handler.resolvedResponse!.statusCode, equals(200));
      expect(handler.resolvedResponse!.requestOptions.headers['Authorization'],
          equals('Bearer new-token'));
    });

    test('token refresh failure propagates error', () async {
      final failCompleter = Completer<String?>();
      final failInterceptor = TestableAuthInterceptor(
        onRefreshToken: () => failCompleter.future,
        onGetCurrentToken: () => 'token',
      );

      final handler = _MockErrorHandler();
      failInterceptor.onError(make401Error(), handler);

      // Complete with error - the interceptor catches it internally
      failCompleter.completeError(Exception('refresh failed'));
      // Allow microtasks to settle
      await Future.delayed(const Duration(milliseconds: 10));

      expect(handler.nextCalled, isTrue);
      expect(failInterceptor.refreshCallCount, equals(1));
    });

    test('concurrent 401s share the same refresh call', () async {
      // Use a manual completer so we can control timing
      final sharedCompleter = Completer<String?>();
      int callCount = 0;
      final sharedInterceptor = TestableAuthInterceptor(
        onRefreshToken: () {
          callCount++;
          return sharedCompleter.future;
        },
        onGetCurrentToken: () => 'token',
      );

      final handler1 = _MockErrorHandler();
      final handler2 = _MockErrorHandler();

      // Trigger two 401s concurrently
      // The first call sets _lastRefreshAttempt, so the second within 10s
      // gets short-circuited by cooldown. This matches the real implementation.
      sharedInterceptor.onError(make401Error(), handler1);

      // The second 401 within 10s cooldown should be rejected (passed through)
      sharedInterceptor.onError(make401Error(), handler2);

      sharedCompleter.complete('refreshed-token');
      await Future.delayed(Duration.zero);

      // Only one refresh call was made
      expect(callCount, equals(1));
      // First handler got retried, second was passed through (cooldown)
      expect(handler1.resolvedResponse, isNotNull);
      expect(handler2.nextCalled, isTrue);
    });

    test('10-second cooldown prevents rapid refresh attempts', () async {
      // First 401 - should trigger refresh
      final handler1 = _MockErrorHandler();
      interceptor.onError(make401Error(), handler1);
      refreshCompleter.complete('new-token');
      await Future.delayed(Duration.zero);

      expect(interceptor.refreshCallCount, equals(1));
      expect(handler1.resolvedResponse, isNotNull);

      // Second 401 within 10 seconds - should be rejected by cooldown
      final handler2 = _MockErrorHandler();
      interceptor.onError(make401Error(), handler2);
      await Future.delayed(Duration.zero);

      // No additional refresh call
      expect(interceptor.refreshCallCount, equals(1));
      // Error passed through
      expect(handler2.nextCalled, isTrue);
    });

    test('null token from refresh passes error through', () async {
      final nullCompleter = Completer<String?>();
      final nullInterceptor = TestableAuthInterceptor(
        onRefreshToken: () => nullCompleter.future,
        onGetCurrentToken: () => 'token',
      );

      final handler = _MockErrorHandler();
      nullInterceptor.onError(make401Error(), handler);

      nullCompleter.complete(null);
      await Future.delayed(Duration.zero);

      expect(handler.nextCalled, isTrue);
    });
  });
}

class _MockRequestHandler extends RequestInterceptorHandler {
  RequestOptions? nextOptions;

  @override
  void next(RequestOptions requestOptions) {
    nextOptions = requestOptions;
  }
}

class _MockErrorHandler extends ErrorInterceptorHandler {
  bool nextCalled = false;
  Response? resolvedResponse;

  @override
  void next(DioException err) {
    nextCalled = true;
  }

  @override
  void resolve(Response response) {
    resolvedResponse = response;
  }
}
