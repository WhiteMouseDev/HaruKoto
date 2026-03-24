import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_config.dart';
import '../../../core/network/auth_refresh_client.dart';

class AuthRepository {
  final SupabaseClient _client;
  final GoogleSignIn _googleSignIn;
  final Dio _authRefreshClient;

  AuthRepository({
    SupabaseClient? client,
    GoogleSignIn? googleSignIn,
    Dio? authRefreshClient,
  })  : _client = client ?? Supabase.instance.client,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: ['email', 'profile'],
              serverClientId: AppConfig.googleServerClientId,
            ),
        _authRefreshClient = authRefreshClient ?? AuthRefreshClient().dio;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;

  bool get isAuthenticated => currentSession != null;

  // --- Google Sign-In ---
  Future<AuthResponse> signInWithGoogle() async {
    final account = await _googleSignIn.signIn();
    if (account == null) {
      throw const AuthException('Google 로그인이 취소되었습니다.');
    }

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null) {
      throw const AuthException('Google ID 토큰을 가져올 수 없습니다.');
    }

    return _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: auth.accessToken,
    );
  }

  // --- Kakao Sign-In (Native SDK + 백엔드 토큰 교환) ---
  Future<AuthResponse> signInWithKakao() async {
    // 1. 네이티브 SDK로 인가 코드 획득 (카카오톡 앱 전환 or 웹 로그인)
    const redirectUri = 'kakao${AppConfig.kakaoNativeAppKey}://oauth';
    String authCode;
    if (await isKakaoTalkInstalled()) {
      authCode = await AuthCodeClient.instance
          .authorizeWithTalk(redirectUri: redirectUri);
    } else {
      authCode =
          await AuthCodeClient.instance.authorize(redirectUri: redirectUri);
    }

    // 2. 백엔드에서 REST API 키로 토큰 교환 → aud가 Supabase 설정과 일치
    final response = await _authRefreshClient.post<Map<String, dynamic>>(
      '/auth/kakao/exchange',
      data: {
        'code': authCode,
        'redirect_uri': redirectUri,
      },
    );

    final data = response.data ?? const <String, dynamic>{};
    final idToken = data['id_token'] as String?;
    if (idToken == null) {
      throw const AuthException('카카오 ID 토큰을 가져올 수 없습니다.');
    }

    // 3. Supabase 인증
    return _client.auth.signInWithIdToken(
      provider: OAuthProvider.kakao,
      idToken: idToken,
    );
  }

  // --- Apple Sign-In ---
  Future<AuthResponse> signInWithApple() async {
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );

    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException('Apple ID 토큰을 가져올 수 없습니다.');
    }

    return _client.auth.signInWithIdToken(
      provider: OAuthProvider.apple,
      idToken: idToken,
    );
  }

  // --- Email Sign-In ---
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // --- Email Sign-Up ---
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    return _client.auth.signUp(
      email: email,
      password: password,
    );
  }

  // --- Password Reset ---
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  // --- Sign Out ---
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _client.auth.signOut();
  }
}
