import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../auth/auth_session_manager.dart';
import 'app_http_client.dart';
import 'network_base.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required AuthSessionManager authSessionManager,
    required ReplayRequest replayRequest,
  })  : _authSessionManager = authSessionManager,
        _replayRequest = replayRequest;

  final AuthSessionManager _authSessionManager;
  final ReplayRequest _replayRequest;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final accessToken = _authSessionManager.currentAccessToken;
    if (accessToken != null) {
      options.headers['Authorization'] = 'Bearer $accessToken';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final metadata = err.requestOptions.extra;
    if (err.response?.statusCode != 401 ||
        metadata[RequestMetadata.skipAuthRefresh] == true) {
      handler.next(err);
      return;
    }

    try {
      final newToken = await _authSessionManager.refreshAccessToken();
      if (newToken == null) {
        await _signOutQuietly();
        handler.next(err);
        return;
      }

      final requestOptions = err.requestOptions;
      requestOptions.headers['Authorization'] = 'Bearer $newToken';
      requestOptions.extra[RequestMetadata.retryReason] = 'auth_refresh';

      try {
        final retryResponse = await _replayRequest(requestOptions);
        handler.resolve(retryResponse);
        return;
      } on DioException catch (retryError) {
        handler.next(retryError);
        return;
      }
    } catch (e) {
      debugPrint('[AuthInterceptor] Token refresh failed: $e');
      await _signOutQuietly();
      handler.next(err);
    }
  }

  Future<void> _signOutQuietly() async {
    try {
      await _authSessionManager.signOut();
    } catch (e) {
      debugPrint('[AuthInterceptor] Sign-out failed: $e');
    }
  }
}
