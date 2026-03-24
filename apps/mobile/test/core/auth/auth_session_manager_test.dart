import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/auth_session_manager.dart';

void main() {
  group('AuthSessionManager', () {
    test('reads the current access token from the store', () {
      final store = _FakeAuthSessionStore(currentToken: 'current-token');
      final manager = AuthSessionManager(store: store);

      expect(manager.currentAccessToken, equals('current-token'));
    });

    test('shares a single refresh request while one is in flight', () async {
      final completer = Completer<String?>();
      final store = _FakeAuthSessionStore(
        onRefresh: () => completer.future,
      );
      final manager = AuthSessionManager(store: store);

      final first = manager.refreshAccessToken();
      final second = manager.refreshAccessToken();

      expect(store.refreshCallCount, equals(1));

      completer.complete('refreshed-token');

      await expectLater(first, completion('refreshed-token'));
      await expectLater(second, completion('refreshed-token'));
    });

    test('enforces cooldown between refresh attempts', () async {
      final store = _FakeAuthSessionStore(
        onRefresh: () async => 'refreshed-token',
      );
      final manager = AuthSessionManager(store: store);

      await expectLater(
        manager.refreshAccessToken(),
        completion('refreshed-token'),
      );
      await expectLater(manager.refreshAccessToken(), completion(isNull));

      expect(store.refreshCallCount, equals(1));
    });

    test('recovers after a failed refresh once cooldown is disabled', () async {
      var shouldFail = true;
      final store = _FakeAuthSessionStore(
        onRefresh: () async {
          if (shouldFail) {
            throw Exception('refresh failed');
          }
          return 'recovered-token';
        },
      );
      final manager = AuthSessionManager(
        store: store,
        refreshCooldown: Duration.zero,
      );

      await expectLater(
        manager.refreshAccessToken(),
        throwsA(isA<Exception>()),
      );

      shouldFail = false;

      await expectLater(
        manager.refreshAccessToken(),
        completion('recovered-token'),
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
    return onRefresh?.call();
  }

  @override
  Future<void> signOut() async {
    signOutCallCount++;
  }
}
