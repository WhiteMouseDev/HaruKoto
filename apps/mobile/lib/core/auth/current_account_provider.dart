import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_provider.dart';

/// Identity only. Credentials and session mutation remain in the auth layer.
/// Read at action boundaries as auth stream delivery can lag a session switch.
final currentAccountReaderProvider = Provider<String? Function()>((ref) {
  return () => ref.read(authRepositoryProvider).currentSession?.user.id;
});

final currentAccountIdProvider = Provider<String?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(currentAccountReaderProvider)();
});
