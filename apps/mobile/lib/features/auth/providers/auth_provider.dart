import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/dio_provider.dart';
import '../data/auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    authRefreshClient: ref.watch(authRefreshClientProvider).dio,
  );
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  // A temporary refresh error can be emitted while Supabase still has a
  // session. Use the stream as a signal to re-read the actual session.
  ref.watch(authStateProvider);
  return ref.watch(authRepositoryProvider).isAuthenticated;
});
