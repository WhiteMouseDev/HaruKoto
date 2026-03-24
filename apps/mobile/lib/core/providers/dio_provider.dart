import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_session_manager.dart';
import '../network/app_http_client.dart';
import '../network/auth_refresh_client.dart';

final authSessionManagerProvider = Provider<AuthSessionManager>((ref) {
  return AuthSessionManager();
});

final authRefreshClientProvider = Provider<AuthRefreshClient>((ref) {
  final client = AuthRefreshClient();
  ref.onDispose(() => client.close(force: true));
  return client;
});

final appHttpClientProvider = Provider<AppHttpClient>((ref) {
  final client = AppHttpClient(
    authSessionManager: ref.watch(authSessionManagerProvider),
    authRefreshClient: ref.watch(authRefreshClientProvider),
  );
  ref.onDispose(() => client.close(force: true));
  return client;
});

final dioProvider = Provider<Dio>((ref) {
  return ref.watch(appHttpClientProvider).dio;
});
