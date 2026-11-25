import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/auth_session_manager.dart';

import 'auth_session_fixture.dart';

void main() {
  final initialToken = fixtureAccessToken('initial-login', 100);
  final updatedToken = fixtureAccessToken('initial-login', 200);
  group('AuthSessionManager', () {
    test('reads the current access token from the store', () {
      final store = _FakeAuthSessionStore(currentToken: 'current-token');
      final manager = AuthSessionManager(store: store);

      expect(manager.currentAccessToken, equals('current-token'));
    });

    test('shares a single refresh request while one is in flight', () async {
      final completer = Completer<String?>();
      final store = _FakeAuthSessionStore(
        currentToken: initialToken,
        onRefresh: () => completer.future,
      );
      final manager = AuthSessionManager(store: store);

      final first = manager.recoverAccessToken(initialToken);
      final second = manager.recoverAccessToken(initialToken);

      expect(store.refreshCallCount, equals(1));

      completer.complete(updatedToken);

      await expectLater(first, completion(updatedToken));
      await expectLater(second, completion(updatedToken));
    });

    test('enforces cooldown between refresh attempts', () async {
      final store = _FakeAuthSessionStore(
        currentToken: initialToken,
        onRefresh: () async => updatedToken,
      );
      final manager = AuthSessionManager(store: store);

      await expectLater(
        manager.recoverAccessToken(initialToken),
        completion(updatedToken),
      );
      await expectLater(
          manager.recoverAccessToken(updatedToken), completion(isNull));

      expect(store.refreshCallCount, equals(1));
    });

    test('does not reuse another account refresh or apply its cooldown',
        () async {
      final completer = Completer<String?>();
      final nextToken =
          fixtureAccessToken('other-login', 200, userId: 'other-user');
      final nextRefreshedToken =
          fixtureAccessToken('other-login', 300, userId: 'other-user');
      final store = _FakeAuthSessionStore(
        currentToken: initialToken,
        onRefresh: () => completer.future,
      );
      final manager = AuthSessionManager(store: store);

      final original = manager.recoverAccessToken(initialToken);
      store.currentToken = nextToken;
      expect(await manager.recoverAccessToken(nextToken), isNull);
      completer.complete(updatedToken);
      expect(await original, isNull);
      expect(store.refreshCallCount, 1);

      store.onRefresh = () async => nextRefreshedToken;
      expect(await manager.recoverAccessToken(nextToken), nextRefreshedToken);
      expect(store.refreshCallCount, 2);
    });

    test('recovers after a failed refresh once cooldown is disabled', () async {
      var shouldFail = true;
      final store = _FakeAuthSessionStore(
        currentToken: initialToken,
        onRefresh: () async {
          if (shouldFail) {
            throw Exception('refresh failed');
          }
          return updatedToken;
        },
      );
      final manager = AuthSessionManager(
        store: store,
        refreshCooldown: Duration.zero,
      );

      await expectLater(
        manager.recoverAccessToken(initialToken),
        throwsA(isA<Exception>()),
      );

      shouldFail = false;

      await expectLater(
        manager.recoverAccessToken(initialToken),
        completion(updatedToken),
      );
      expect(store.refreshCallCount, equals(2));
    });
  });
}

class _FakeAuthSessionStore implements AuthSessionStore {
  _FakeAuthSessionStore({
    this.currentToken,
    this.onRefresh,
  });

  String? currentToken;
  Future<String?> Function()? onRefresh;

  int refreshCallCount = 0;
  int signOutCallCount = 0;

  @override
  String? get currentAccessToken => currentToken;

  @override
  Future<String?> refreshAccessToken() async {
    refreshCallCount++;
    final oldToken = currentToken;
    final token = await onRefresh?.call();
    if (token != null && currentToken == oldToken) currentToken = token;
    return token;
  }

  @override
  Future<void> signOut() async {
    signOutCallCount++;
  }
}
