import 'package:dio/dio.dart';

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
  static const _bearerPrefix = 'Bearer ';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final accessToken = _authSessionManager.currentAccessToken;
    if (accessToken != null) {
      options.headers['Authorization'] = '$_bearerPrefix$accessToken';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final requestOptions = err.requestOptions;
    final metadata = requestOptions.extra;
    final authorization = requestOptions.headers['Authorization'];
    if (err.response?.statusCode != 401 ||
        metadata[RequestMetadata.skipAuthRefresh] == true ||
        requestOptions.cancelToken?.isCancelled == true ||
        authorization is! String ||
        !authorization.startsWith(_bearerPrefix) ||
        authorization.length == _bearerPrefix.length) {
      handler.next(err);
      return;
    }

    String? newToken;
    try {
      newToken = await _authSessionManager.recoverAccessToken(
        authorization.substring(_bearerPrefix.length),
      );
    } catch (_) {
      // Supabase owns session invalidation. A temporary refresh error must
      // leave the existing session available so the screen can offer a retry.
      handler.next(err);
      return;
    }
    if (newToken == null ||
        newToken != _authSessionManager.currentAccessToken ||
        requestOptions.cancelToken?.isCancelled == true) {
      handler.next(err);
      return;
    }

    requestOptions.headers['Authorization'] = '$_bearerPrefix$newToken';
    metadata[RequestMetadata.retryReason] = 'auth_refresh';
    try {
      handler.resolve(await _replayRequest(requestOptions));
    } on DioException catch (retryError) {
      handler.next(retryError);
    } catch (_) {
      handler.next(err);
    }
  }
}
