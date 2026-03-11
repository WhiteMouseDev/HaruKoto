import 'package:dio/dio.dart';
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

  dio.interceptors.addAll([
    AuthInterceptor(),
    _ErrorInterceptor(),
  ]);

  return dio;
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response != null) {
      final exception = ApiException.fromResponse(
        err.response?.statusCode,
        err.response?.data,
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

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        type: err.type,
        error: ApiException(
          message: err.message ?? '네트워크 오류가 발생했습니다.',
        ),
      ),
    );
  }
}
