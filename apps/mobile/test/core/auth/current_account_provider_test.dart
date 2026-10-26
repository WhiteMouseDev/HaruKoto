import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/features/auth/data/auth_repository.dart';
import 'package:harukoto_mobile/features/auth/providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test(
      'account identity uses current repository session even with a stale stream value',
      () async {
    final repository = _IdentityOnlyRepository()
      ..session = _IdentityOnlySession('account-a');
    final container = ProviderContainer(overrides: [
      authRepositoryProvider.overrideWithValue(repository),
      authStateProvider.overrideWith((ref) => const Stream.empty()),
    ]);
    addTearDown(container.dispose);
    expect(container.read(currentAccountIdProvider), 'account-a');
    repository.session = _IdentityOnlySession('account-b');
    expect(container.read(currentAccountIdProvider), 'account-a');
    expect(container.read(currentAccountReaderProvider)(), 'account-b');
    repository.session = null;
    expect(container.read(currentAccountReaderProvider)(), isNull);
    // The fake Session implements only user. Any credential read, refresh,
    // sign-out, or auth mutation would throw through Fake.noSuchMethod.
  });
}

class _IdentityOnlyRepository extends Fake implements AuthRepository {
  Session? session;
  @override
  Session? get currentSession => session;
}

class _IdentityOnlySession extends Fake implements Session {
  _IdentityOnlySession(this.id);
  final String id;
  @override
  User get user => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: '2026-01-01');
}
