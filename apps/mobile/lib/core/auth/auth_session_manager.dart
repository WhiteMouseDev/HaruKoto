import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AuthSessionStore {
  String? get currentAccessToken;

  Future<String?> refreshAccessToken();

  Future<void> signOut();
}

class SupabaseAuthSessionStore implements AuthSessionStore {
  SupabaseAuthSessionStore({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  String? get currentAccessToken => _client.auth.currentSession?.accessToken;

  @override
  Future<String?> refreshAccessToken() async {
    final response = await _client.auth.refreshSession();
    return response.session?.accessToken;
  }

  @override
  Future<void> signOut() {
    return _client.auth.signOut();
  }
}

class AuthSessionManager {
  AuthSessionManager({
    AuthSessionStore? store,
    Duration refreshCooldown = const Duration(seconds: 10),
  })  : _store = store ?? SupabaseAuthSessionStore(),
        _refreshCooldown = refreshCooldown;

  final AuthSessionStore _store;
  final Duration _refreshCooldown;

  Completer<String?>? _refreshCompleter;
  DateTime? _lastRefreshAttempt;

  String? get currentAccessToken => _store.currentAccessToken;

  Future<String?> refreshAccessToken() {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final now = DateTime.now();
    if (_lastRefreshAttempt != null &&
        now.difference(_lastRefreshAttempt!) < _refreshCooldown) {
      return Future<String?>.value(null);
    }

    _lastRefreshAttempt = now;
    final completer = Completer<String?>();
    _refreshCompleter = completer;

    () async {
      try {
        completer.complete(await _store.refreshAccessToken());
      } catch (error, stackTrace) {
        unawaited(completer.future.catchError((Object _) => null));
        completer.completeError(error, stackTrace);
      } finally {
        _refreshCompleter = null;
      }
    }();

    return completer.future;
  }

  Future<void> signOut() {
    return _store.signOut();
  }
}
