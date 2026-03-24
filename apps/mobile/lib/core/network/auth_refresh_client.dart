import 'package:dio/dio.dart';

import 'network_base.dart';

class AuthRefreshClient {
  AuthRefreshClient({Dio? dio}) : _dio = dio ?? _buildClient();

  final Dio _dio;

  Dio get dio => _dio;

  Future<Response<T>> replay<T>(RequestOptions requestOptions) {
    return _dio.request<T>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      cancelToken: requestOptions.cancelToken,
      options: Options(
        method: requestOptions.method,
        headers: Map<String, dynamic>.from(requestOptions.headers),
        responseType: requestOptions.responseType,
        contentType: requestOptions.contentType,
        sendTimeout: requestOptions.sendTimeout,
        receiveTimeout: requestOptions.receiveTimeout,
        receiveDataWhenStatusError: requestOptions.receiveDataWhenStatusError,
        followRedirects: requestOptions.followRedirects,
        maxRedirects: requestOptions.maxRedirects,
        persistentConnection: requestOptions.persistentConnection,
        requestEncoder: requestOptions.requestEncoder,
        responseDecoder: requestOptions.responseDecoder,
        validateStatus: requestOptions.validateStatus,
        listFormat: requestOptions.listFormat,
        extra: Map<String, dynamic>.from(requestOptions.extra)
          ..[RequestMetadata.skipAuthRefresh] = true
          ..[RequestMetadata.skipNetworkRetry] = true,
      ),
    );
  }

  void close({bool force = false}) {
    _dio.close(force: force);
  }

  static Dio _buildClient() {
    final dio = Dio(createApiBaseOptions());
    attachClientDiagnostics(dio);
    return dio;
  }
}
