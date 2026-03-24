import 'package:dio/dio.dart';

import '../auth/auth_session_manager.dart';
import 'auth_interceptor.dart';
import 'auth_refresh_client.dart';
import 'network_base.dart';

typedef ReplayRequest = Future<Response<dynamic>> Function(
  RequestOptions requestOptions,
);

class AppHttpClient {
  AppHttpClient({
    required AuthSessionManager authSessionManager,
    required AuthRefreshClient authRefreshClient,
  }) : dio = Dio(createApiBaseOptions()) {
    dio.interceptors.add(
      AuthInterceptor(
        authSessionManager: authSessionManager,
        replayRequest: authRefreshClient.replay,
      ),
    );
    dio.interceptors.add(
      _RetryInterceptor(replayRequest: authRefreshClient.replay),
    );
    attachClientDiagnostics(dio);
  }

  final Dio dio;

  void close({bool force = false}) {
    dio.close(force: force);
  }
}

class _RetryInterceptor extends Interceptor {
  _RetryInterceptor({required ReplayRequest replayRequest})
      : _replayRequest = replayRequest;

  static const _maxRetries = 2;
  static const _idempotentMethods = {'GET', 'HEAD', 'OPTIONS', 'PUT', 'DELETE'};

  final ReplayRequest _replayRequest;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final metadata = err.requestOptions.extra;
    if (metadata[RequestMetadata.skipNetworkRetry] == true) {
      handler.next(err);
      return;
    }

    final method = err.requestOptions.method.toUpperCase();
    if (!_idempotentMethods.contains(method)) {
      handler.next(err);
      return;
    }

    final isRetryable = _isServerError(err) ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError;
    if (!isRetryable) {
      handler.next(err);
      return;
    }

    final retryCount = (metadata[RequestMetadata.retryCount] as int?) ?? 0;
    if (retryCount >= _maxRetries) {
      handler.next(err);
      return;
    }

    await Future<void>.delayed(Duration(seconds: 1 << retryCount));

    metadata[RequestMetadata.retryCount] = retryCount + 1;
    metadata[RequestMetadata.retryReason] = 'network';

    try {
      final response = await _replayRequest(err.requestOptions);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  bool _isServerError(DioException err) {
    final statusCode = err.response?.statusCode;
    return statusCode != null && statusCode >= 500;
  }
}
