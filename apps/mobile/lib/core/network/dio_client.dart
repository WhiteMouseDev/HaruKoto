import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../constants/app_config.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';

Dio createDioClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: '${AppConfig.apiBaseUrl}/api/v1',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.add(AuthInterceptor());
  dio.interceptors.add(_RetryInterceptor());
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
      error: true,
      logPrint: (msg) => debugPrint('[DIO] $msg'),
    ));
  }
  dio.interceptors.add(_ErrorInterceptor());

  return dio;
}

class _RetryInterceptor extends Interceptor {
  static const _maxRetries = 2;
  static const _idempotentMethods = {'GET', 'HEAD', 'OPTIONS', 'PUT', 'DELETE'};

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
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

    final retryCount = (err.requestOptions.extra['_retryCount'] as int?) ?? 0;
    if (retryCount >= _maxRetries) {
      handler.next(err);
      return;
    }

    final delay = Duration(seconds: 1 << retryCount); // 1s, 2s
    await Future<void>.delayed(delay);

    err.requestOptions.extra['_retryCount'] = retryCount + 1;
    try {
      final dio = Dio(BaseOptions(
        baseUrl: err.requestOptions.baseUrl,
        connectTimeout: err.requestOptions.connectTimeout,
        receiveTimeout: err.requestOptions.receiveTimeout,
      ));
      final response = await dio.fetch(err.requestOptions);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  bool _isServerError(DioException err) {
    final statusCode = err.response?.statusCode;
    return statusCode != null && statusCode >= 500;
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final path = err.requestOptions.path;
    if (err.response != null) {
      final statusCode = err.response?.statusCode;
      if (statusCode != null && statusCode >= 500) {
        Sentry.captureException(err, stackTrace: err.stackTrace);
      }
      final exception = ApiException.fromResponse(
        statusCode,
        err.response?.data,
        requestPath: path,
      );
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          response: err.response,
          type: err.type,
          error: exception,
        ),
      );
      return;
    }

    Sentry.captureException(err, stackTrace: err.stackTrace);
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        type: err.type,
        error: ApiException(
          message: err.message ?? '네트워크 오류가 발생했습니다.',
          requestPath: path,
        ),
      ),
    );
  }
}
