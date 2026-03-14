class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;
  final String? requestPath;

  const ApiException({
    required this.message,
    this.statusCode,
    this.errorCode,
    this.requestPath,
  });

  factory ApiException.fromResponse(
    int? statusCode,
    dynamic data, {
    String? requestPath,
  }) {
    String message = '알 수 없는 오류가 발생했습니다.';
    String? errorCode;
    if (data is Map<String, dynamic>) {
      if (data.containsKey('detail')) {
        message = data['detail'] as String;
      }
      if (data.containsKey('errorCode')) {
        errorCode = data['errorCode'] as String;
      }
    }
    return ApiException(
      message: message,
      statusCode: statusCode,
      errorCode: errorCode,
      requestPath: requestPath,
    );
  }

  String get userMessage {
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
  String toString() => 'ApiException($statusCode): $message';
}
