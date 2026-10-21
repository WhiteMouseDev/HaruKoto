import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;
  final String? requestPath;
  final dynamic details;

  const ApiException({
    required this.message,
    this.statusCode,
    this.errorCode,
    this.requestPath,
    this.details,
  });

  factory ApiException.fromDioException(DioException exception) {
    final mapped = exception.error;
    if (mapped is ApiException) return mapped;

    final response = exception.response;
    if (response != null) {
      return ApiException.fromResponse(
        response.statusCode,
        response.data,
        requestPath: exception.requestOptions.path,
      );
    }

    return ApiException(
      // 진단용 원문은 보존하고 사용자 안내는 오류 코드로 변환한다.
      message: exception.message ?? '네트워크 오류가 발생했습니다.',
      errorCode: switch (exception.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'NETWORK_TIMEOUT',
        DioExceptionType.badCertificate => 'NETWORK_SECURITY_ERROR',
        DioExceptionType.cancel => 'REQUEST_CANCELLED',
        _ => 'NETWORK_ERROR',
      },
      requestPath: exception.requestOptions.path,
    );
  }

  factory ApiException.fromResponse(
    int? statusCode,
    dynamic data, {
    String? requestPath,
  }) {
    String message = '알 수 없는 오류가 발생했습니다.';
    String? errorCode;
    dynamic details;

    if (data is Map<String, dynamic>) {
      // 표준 형식: {"error": {"code": "...", "message": "...", "details": ...}}
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        final code = error['code'];
        final msg = error['message'];
        if (code is String) errorCode = code;
        if (msg is String && msg.isNotEmpty) message = msg;
        details = error['details'];
      }
      // 레거시 형식: {"detail": "...", "errorCode": "..."}
      final legacyErrorCode = data['errorCode'] ?? data['code'];
      if (legacyErrorCode is String && legacyErrorCode.isNotEmpty) {
        errorCode ??= legacyErrorCode;
      }
      // 레거시 형식: {"detail": "..."}
      if (data.containsKey('detail')) {
        final detail = data['detail'];
        if (detail is String && detail.isNotEmpty) {
          message = detail;
        } else if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is String && first.isNotEmpty) {
            message = first;
          } else if (first is Map<String, dynamic>) {
            final msg = first['msg'];
            if (msg is String && msg.isNotEmpty) {
              message = msg;
            } else {
              message = first.toString();
            }
          } else {
            message = first.toString();
          }
        } else if (detail != null) {
          message = detail.toString();
        }
      }
    }

    return ApiException(
      message: message,
      statusCode: statusCode,
      errorCode: errorCode,
      requestPath: requestPath,
      details: details,
    );
  }

  bool get isAuth => errorCode != null && errorCode!.startsWith('AUTH_');
  bool get isValidation => errorCode == 'VALIDATION_ERROR';
  bool get isRateLimited => errorCode == 'RATE_LIMITED';
  bool get isNotFound => errorCode != null && errorCode!.endsWith('_NOT_FOUND');

  String get userMessage {
    if (statusCode == null) {
      switch (errorCode) {
        case 'NETWORK_TIMEOUT':
          return '서버 응답이 늦어지고 있어요. 잠시 후 다시 시도해 주세요.';
        case 'NETWORK_ERROR':
          return '네트워크 연결을 확인한 뒤 다시 시도해 주세요.';
        case 'NETWORK_SECURITY_ERROR':
          return '서버에 안전하게 연결하지 못했어요. 잠시 후 다시 시도해 주세요.';
        case 'REQUEST_CANCELLED':
          return '요청이 취소되었어요. 다시 시도해 주세요.';
      }
    }
    switch (statusCode) {
      case 400:
        return '잘못된 요청입니다.';
      case 401:
        return '로그인이 필요합니다.';
      case 403:
        return '접근 권한이 없습니다.';
      case 404:
        return '요청한 데이터를 찾을 수 없습니다.';
      case 409:
        return '이미 처리된 요청입니다.';
      case 422:
        return '입력값을 확인해주세요.';
      case 429:
        return '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.';
      case final code? when code >= 500:
        return '서버 오류가 발생했습니다. 잠시 후 다시 시도해주세요.';
      default:
        return message;
    }
  }

  @override
  String toString() => errorCode == null
      ? 'ApiException($statusCode): $message'
      : 'ApiException($statusCode, $errorCode): $message';
}
