import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/auth_session_manager.dart';
import 'package:harukoto_mobile/core/network/auth_interceptor.dart';

import '../auth/auth_session_fixture.dart';

void main() {
  final expiredToken = fixtureAccessToken('original', 100);
  final refreshedToken = fixtureAccessToken('original', 200);

  group('AuthInterceptor', () {
    late _FakeAuthSessionStore store;
    late AuthSessionManager sessionManager;
    late Response<dynamic> replayResponse;
    late RequestOptions replayedRequest;
    late AuthInterceptor interceptor;

    setUp(() {
      store = _FakeAuthSessionStore(currentToken: expiredToken);
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

    DioException make401Error({String? token, bool withBearer = true}) {
      final opts = RequestOptions(
        path: '/wordbook/',
        headers: withBearer
            ? {'Authorization': 'Bearer ${token ?? expiredToken}'}
            : null,
      );
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

      refreshCompleter.complete(refreshedToken);
      await Future.delayed(Duration.zero);

      expect(store.refreshCallCount, equals(1));
      expect(handler.resolvedResponse, isNotNull);
      expect(handler.resolvedResponse!.statusCode, equals(200));
      expect(
          replayedRequest.headers['Authorization'], 'Bearer $refreshedToken');
    });

    test('temporary refresh failure keeps the session and forwards the error',
        () async {
      store.onRefresh = () async => throw const SocketException('offline');
      final handler = _MockErrorHandler();
      interceptor.onError(make401Error(), handler);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(handler.nextCalled, isTrue);
      expect(store.refreshCallCount, equals(1));
      expect(store.currentToken, expiredToken);
      expect(store.signOutCallCount, 0);
    });

    test(
        'a late wordbook 401 uses the token already refreshed for this session',
        () async {
      store.onRefresh = () async => refreshedToken;

      interceptor.onError(make401Error(), _MockErrorHandler());
      await Future<void>.delayed(Duration.zero);
      final lateHandler = _MockErrorHandler();
      interceptor.onError(make401Error(), lateHandler);
      await Future<void>.delayed(Duration.zero);

      expect(lateHandler.resolvedResponse, isNotNull);
      expect(
          replayedRequest.headers['Authorization'], 'Bearer $refreshedToken');
      expect(store.refreshCallCount, 1);
      expect(store.signOutCallCount, 0);
    });

    test('a late 401 cannot use a new sign-in even for the same user',
        () async {
      store.currentToken = fixtureAccessToken('second-login', 200);
      final handler = _MockErrorHandler();
      interceptor.onError(make401Error(), handler);
      await Future<void>.delayed(Duration.zero);

      expect(handler.resolvedResponse, isNull);
      expect(handler.nextCalled, isTrue);
      expect(store.refreshCallCount, 0);
      expect(store.signOutCallCount, 0);
    });

    test('a 401 without a bearer does not refresh the current session',
        () async {
      final handler = _MockErrorHandler();
      interceptor.onError(make401Error(withBearer: false), handler);
      await Future<void>.delayed(Duration.zero);

      expect(handler.nextCalled, isTrue);
      expect(store.refreshCallCount, 0);
      expect(store.signOutCallCount, 0);
    });

    test('a 401 for the fresh token during cooldown keeps the session',
        () async {
      store.onRefresh = () async => refreshedToken;
      interceptor.onError(make401Error(), _MockErrorHandler());
      await Future<void>.delayed(Duration.zero);

      final handler = _MockErrorHandler();
      interceptor.onError(make401Error(token: refreshedToken), handler);
      await Future<void>.delayed(Duration.zero);

      expect(handler.nextCalled, isTrue);
      expect(handler.resolvedResponse, isNull);
      expect(store.refreshCallCount, 1);
      expect(store.signOutCallCount, 0);
    });

    test('retry failure is forwarded without forcing sign out', () async {
      store.onRefresh = () async => refreshedToken;
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

    test('null token from refresh forwards the error without signing out',
        () async {
      store.onRefresh = () async => null;
      final handler = _MockErrorHandler();

      interceptor.onError(make401Error(), handler);
      await Future.delayed(Duration.zero);

      expect(handler.nextCalled, isTrue);
      expect(store.signOutCallCount, 0);
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
    final oldToken = currentToken;
    final token = await (onRefresh?.call() ?? Future.value(oldToken));
    if (token != null && currentToken == oldToken) currentToken = token;
    return token;
  }

  @override
  Future<void> signOut() async {
    signOutCallCount++;
    currentToken = null;
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
