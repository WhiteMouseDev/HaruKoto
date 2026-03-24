import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/auth_session_manager.dart';
import 'package:harukoto_mobile/core/network/auth_interceptor.dart';

void main() {
  group('AuthInterceptor', () {
    late _FakeAuthSessionStore store;
    late AuthSessionManager sessionManager;
    late Response<dynamic> replayResponse;
    late RequestOptions replayedRequest;
    late AuthInterceptor interceptor;

    setUp(() {
      store = _FakeAuthSessionStore(currentToken: 'old-token');
      sessionManager = AuthSessionManager(store: store);
      replayResponse = Response(
        requestOptions: RequestOptions(path: '/test'),
        statusCode: 200,
        data: {'retried': true},
      );
      replayedRequest = replayResponse.requestOptions;
      interceptor = AuthInterceptor(
        authSessionManager: sessionManager,
        replayRequest: (requestOptions) async {
          replayedRequest = requestOptions;
          return replayResponse;
        },
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
      store.currentToken = 'my-token';
      final opts = RequestOptions(path: '/test');
      final handler = _MockRequestHandler();

      interceptor.onRequest(opts, handler);

      expect(handler.nextOptions?.headers['Authorization'],
          equals('Bearer my-token'));
    });

    test('does not attach token when no session', () {
      store.currentToken = null;
      final opts = RequestOptions(path: '/test');
      final handler = _MockRequestHandler();

      interceptor.onRequest(opts, handler);

      expect(handler.nextOptions?.headers['Authorization'], isNull);
    });

    test('non-401 errors pass through', () {
      final handler = _MockErrorHandler();
      interceptor.onError(make500Error(), handler);

      expect(handler.nextCalled, isTrue);
      expect(store.refreshCallCount, equals(0));
    });

    test('401 triggers token refresh and retries request', () async {
      final refreshCompleter = Completer<String?>();
      store.onRefresh = () => refreshCompleter.future;
      final handler = _MockErrorHandler();

      interceptor.onError(make401Error(), handler);

      refreshCompleter.complete('new-token');
      await Future.delayed(Duration.zero);

      expect(store.refreshCallCount, equals(1));
      expect(handler.resolvedResponse, isNotNull);
      expect(handler.resolvedResponse!.statusCode, equals(200));
      expect(
          replayedRequest.headers['Authorization'], equals('Bearer new-token'));
    });

    test('refresh failure signs out and propagates error', () async {
      store.onRefresh = () async => throw Exception('refresh failed');
      final handler = _MockErrorHandler();
      interceptor.onError(make401Error(), handler);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(handler.nextCalled, isTrue);
      expect(store.refreshCallCount, equals(1));
      expect(store.signOutCallCount, equals(1));
    });

    test('retry failure is forwarded without forcing sign out', () async {
      store.onRefresh = () async => 'new-token';
      interceptor = AuthInterceptor(
        authSessionManager: sessionManager,
        replayRequest: (requestOptions) async {
          throw DioException(
            requestOptions: requestOptions,
            response: Response(requestOptions: requestOptions, statusCode: 500),
            type: DioExceptionType.badResponse,
          );
        },
      );
      final handler = _MockErrorHandler();
      interceptor.onError(make401Error(), handler);
      await Future.delayed(Duration.zero);

      expect(handler.nextCalled, isTrue);
      expect(store.signOutCallCount, equals(0));
    });

    test('null token from refresh signs out and passes error through',
        () async {
      store.onRefresh = () async => null;
      final handler = _MockErrorHandler();

      interceptor.onError(make401Error(), handler);
      await Future.delayed(Duration.zero);

      expect(handler.nextCalled, isTrue);
      expect(store.signOutCallCount, equals(1));
    });
  });
}

class _FakeAuthSessionStore implements AuthSessionStore {
  _FakeAuthSessionStore({this.currentToken});

  String? currentToken;

  Future<String?> Function()? onRefresh;
  Future<void> Function()? onSignOut;

  int refreshCallCount = 0;
  int signOutCallCount = 0;

  @override
  String? get currentAccessToken => currentToken;

  @override
  Future<String?> refreshAccessToken() async {
    refreshCallCount++;
    return onRefresh?.call() ?? currentToken;
  }

  @override
  Future<void> signOut() async {
    signOutCallCount++;
    await onSignOut?.call();
  }
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
