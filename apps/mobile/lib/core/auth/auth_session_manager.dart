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

  Future<String?>? _refreshInFlight;
  ({String token, DateTime time})? _lastRefresh;

  String? get currentAccessToken => _store.currentAccessToken;

  Future<String?> recoverAccessToken(String rejectedToken) async {
    final currentToken = currentAccessToken;
    if (currentToken == null) return null;
    if (currentToken != rejectedToken) {
      // A slower 401 can arrive after another request refreshed the token.
      return _isSameSession(currentToken, rejectedToken) ? currentToken : null;
    }

    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      if (_lastRefresh?.token != rejectedToken) return null;
      await inFlight;
    } else {
      final now = DateTime.now();
      final lastRefresh = _lastRefresh;
      if (lastRefresh != null &&
          now.difference(lastRefresh.time) < _refreshCooldown &&
          _isSameSession(lastRefresh.token, rejectedToken)) {
        return null;
      }
      _lastRefresh = (token: rejectedToken, time: now);
      final refresh = Future<String?>.sync(_store.refreshAccessToken);
      _refreshInFlight = refresh;
      try {
        await refresh;
      } finally {
        _refreshInFlight = null;
      }
    }

    // Read the live session again. Refresh can overlap a logout or a new login.
    final refreshedToken = currentAccessToken;
    if (refreshedToken == null || refreshedToken == rejectedToken) return null;
    return _isSameSession(refreshedToken, rejectedToken)
        ? refreshedToken
        : null;
  }

  bool _isSameSession(String first, String second) {
    if (first == second) return true;
    try {
      final firstClaims = decodeJwt(first).payload;
      final secondClaims = decodeJwt(second).payload;
      final sessionId = firstClaims.claims['session_id'];
      return sessionId is String &&
          sessionId.isNotEmpty &&
          sessionId == secondClaims.claims['session_id'] &&
          firstClaims.sub != null &&
          firstClaims.sub == secondClaims.sub;
    } on AuthInvalidJwtException {
      return false;
    }
  }

  Future<void> signOut() {
    return _store.signOut();
  }
}
