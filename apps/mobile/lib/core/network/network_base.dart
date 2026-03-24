import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../constants/app_config.dart';
import 'api_exception.dart';

abstract final class RequestMetadata {
  static const retryCount = '_retryCount';
  static const retryReason = '_retryReason';
  static const skipAuthRefresh = '_skipAuthRefresh';
  static const skipNetworkRetry = '_skipNetworkRetry';
}

BaseOptions createApiBaseOptions() {
  return BaseOptions(
    baseUrl: '${AppConfig.apiBaseUrl}/api/v1',
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  );
}

void attachClientDiagnostics(Dio dio) {
  if (kDebugMode) {
    dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
      error: true,
      logPrint: (msg) => debugPrint('[DIO] $msg'),
    ));
  }
  dio.interceptors.add(AppErrorInterceptor());
}

class AppErrorInterceptor extends Interceptor {
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
