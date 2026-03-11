class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException({required this.message, this.statusCode});

  factory ApiException.fromResponse(int? statusCode, dynamic data) {
    String message = '알 수 없는 오류가 발생했습니다.';
    if (data is Map<String, dynamic> && data.containsKey('detail')) {
      message = data['detail'] as String;
    }
    return ApiException(message: message, statusCode: statusCode);
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
