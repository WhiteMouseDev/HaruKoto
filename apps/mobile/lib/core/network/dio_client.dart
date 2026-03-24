import 'package:dio/dio.dart';
import '../auth/auth_session_manager.dart';
import 'app_http_client.dart';
import 'auth_refresh_client.dart';

Dio createDioClient({
  AuthSessionManager? authSessionManager,
  AuthRefreshClient? authRefreshClient,
}) {
  final sessionManager = authSessionManager ?? AuthSessionManager();
  final refreshClient = authRefreshClient ?? AuthRefreshClient();
  return AppHttpClient(
    authSessionManager: sessionManager,
    authRefreshClient: refreshClient,
  ).dio;
}
