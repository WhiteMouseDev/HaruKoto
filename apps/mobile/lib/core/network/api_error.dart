import 'package:dio/dio.dart';

/// 서버 표준 에러 응답을 파싱한 객체.
///
/// 서버 응답 형식:
/// ```json
/// { "error": { "code": "...", "message": "...", "details": ... } }
/// ```
class ApiError {
  const ApiError({
    required this.code,
    required this.message,
    required this.statusCode,
    this.details,
    this.requestId,
  });

  /// 서버 DioException에서 ApiError를 추출. 표준 형식이 아니면 fallback.
  factory ApiError.fromDioException(DioException exception) {
    final response = exception.response;
    final statusCode = response?.statusCode ?? 0;
    final requestId = response?.headers.value('X-Request-Id');

    // 표준 에러 응답 파싱 시도
    if (response?.data is Map<String, dynamic>) {
      final data = response!.data as Map<String, dynamic>;
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        return ApiError(
          code: error['code'] as String? ?? 'SYSTEM_ERROR',
          message: error['message'] as String? ?? '알 수 없는 에러',
          statusCode: statusCode,
          details: error['details'],
          requestId: requestId,
        );
      }
      // 레거시: {"detail": "..."} 형식
      if (data['detail'] != null) {
        return ApiError(
          code: _statusToCode(statusCode),
          message: data['detail'].toString(),
          statusCode: statusCode,
          requestId: requestId,
        );
      }
    }

    // 네트워크 에러 등
    return ApiError(
      code: _dioTypeToCode(exception.type),
      message: exception.message ?? '네트워크 에러가 발생했습니다',
      statusCode: statusCode,
      requestId: requestId,
    );
  }

  final String code;
  final String message;
  final int statusCode;
  final dynamic details;
  final String? requestId;

  bool get isAuth => code.startsWith('AUTH_');
  bool get isValidation => code == 'VALIDATION_ERROR';
  bool get isRateLimited => code == 'RATE_LIMITED';
  bool get isNotFound => code.endsWith('_NOT_FOUND');

  @override
  String toString() => 'ApiError($code: $message)';

  static String _statusToCode(int status) {
    return switch (status) {
      401 => 'AUTH_UNAUTHORIZED',
      403 => 'AUTH_FORBIDDEN',
      404 => 'RESOURCE_NOT_FOUND',
      429 => 'RATE_LIMITED',
      _ => 'SYSTEM_ERROR',
    };
  }

  static String _dioTypeToCode(DioExceptionType type) {
    return switch (type) {
      DioExceptionType.connectionTimeout => 'NETWORK_TIMEOUT',
      DioExceptionType.receiveTimeout => 'NETWORK_TIMEOUT',
      DioExceptionType.connectionError => 'NETWORK_ERROR',
      _ => 'SYSTEM_ERROR',
    };
  }
}
