import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/features/study/data/models/saved_quiz_model.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/providers/saved_quiz_provider.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';

void main() {
  test('failed refresh keeps saved rows and retry targets the first page',
      () async {
    final repository = _Repository();
    final container = _container(repository);
    addTearDown(container.dispose);
    final subscription = container.listen(savedQuizListProvider, (_, __) {});
    addTearDown(subscription.close);
    repository.requests.single.complete(
        SavedQuizPageModel(sessions: [_session('old')], nextCursor: 'older'));
    await container.read(savedQuizListProvider.future);
    final refresh = container.read(savedQuizListProvider.notifier).refresh();
    repository.requests.last.completeError(StateError('offline'));
    await refresh;
    final state = container.read(savedQuizListProvider).requireValue;
    expect(state.sessions.single.id, 'old');
    expect(state.errorOnRefresh, isTrue);
    final retry = container.read(savedQuizListProvider.notifier).refresh();
    repository.requests.last
        .complete(SavedQuizPageModel(sessions: [_session('new')]));
    await retry;
    expect(repository.cursors, [null, null, null]);
    expect(
        container.read(savedQuizListProvider).requireValue.sessions.single.id,
        'new');
  });
  test('empty pages with a cursor can still reach older saved sessions',
      () async {
    final repository = _Repository();
    final container = _container(repository);
    addTearDown(container.dispose);
    final subscription = container.listen(savedQuizListProvider, (_, __) {});
    addTearDown(subscription.close);
    repository.requests.single
        .complete(const SavedQuizPageModel(sessions: [], nextCursor: 'older'));
    final first = await container.read(savedQuizListProvider.future);
    expect(first.sessions, isEmpty);
    expect(first.nextCursor, 'older');
    final loading = container.read(savedQuizListProvider.notifier).loadMore();
    expect(repository.cursors, [null, 'older']);
    repository.requests.last
        .complete(SavedQuizPageModel(sessions: [_session('old-N5')]));
    await loading;
    expect(
        container.read(savedQuizListProvider).requireValue.sessions.single.id,
        'old-N5');
  });

  test('failed next page preserves existing rows and retries the same cursor',
      () async {
    final repository = _Repository();
    final container = _container(repository);
    addTearDown(container.dispose);
    final subscription = container.listen(savedQuizListProvider, (_, __) {});
    addTearDown(subscription.close);
    repository.requests.single.complete(
        SavedQuizPageModel(sessions: [_session('one')], nextCursor: 'next'));
    await container.read(savedQuizListProvider.future);
    final loading = container.read(savedQuizListProvider.notifier).loadMore();
    repository.requests.last.completeError(StateError('offline'));
    await loading;
    var state = container.read(savedQuizListProvider).requireValue;
    expect(state.sessions.single.id, 'one');
    expect(state.nextCursor, 'next');
    expect(state.error, isNotNull);
    final retry = container.read(savedQuizListProvider.notifier).loadMore();
    repository.requests.last.complete(
        SavedQuizPageModel(sessions: [_session('one'), _session('two')]));
    await retry;
    state = container.read(savedQuizListProvider).requireValue;
    expect(state.sessions.map((e) => e.id), ['one', 'two']);
    expect(state.error, isNull);
    expect(repository.cursors, [null, 'next', 'next']);
  });

  test('account switch discards a late page from the former account', () async {
    final repository = _Repository();
    var owner = 'A';
    final container = ProviderContainer(overrides: [
      currentAccountIdProvider.overrideWith((ref) => owner),
      currentAccountReaderProvider.overrideWithValue(() => owner),
      studyRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    final subscription = container.listen(savedQuizListProvider, (_, __) {});
    addTearDown(subscription.close);
    repository.requests.single.complete(SavedQuizPageModel(
        sessions: [_session('A-first')], nextCursor: 'A-more'));
    await container.read(savedQuizListProvider.future);
    final loadingA = container.read(savedQuizListProvider.notifier).loadMore();
    final requestA = repository.requests.last;
    owner = 'B';
    container.invalidate(currentAccountIdProvider);
    final loadingB = container.read(savedQuizListProvider.future);
    repository.requests.last
        .complete(SavedQuizPageModel(sessions: [_session('B-only')]));
    await loadingB;
    requestA.complete(SavedQuizPageModel(sessions: [_session('A-late')]));
    await loadingA;
    final state = container.read(savedQuizListProvider).requireValue;
    expect(state.accountId, 'B');
    expect(state.sessions.map((e) => e.id), ['B-only']);
  });

  test('direct auth change blocks requests even before the auth stream emits',
      () async {
    final repository = _Repository();
    var reader = 'A';
    final container = ProviderContainer(overrides: [
      currentAccountIdProvider.overrideWithValue('A'),
      currentAccountReaderProvider.overrideWithValue(() => reader),
      studyRepositoryProvider.overrideWithValue(repository),
    ]);
    addTearDown(container.dispose);
    final subscription = container.listen(savedQuizListProvider, (_, __) {});
    addTearDown(subscription.close);
    repository.requests.single.complete(
        SavedQuizPageModel(sessions: [_session('A')], nextCursor: 'next'));
    await container.read(savedQuizListProvider.future);
    reader = 'B';
    await container.read(savedQuizListProvider.notifier).loadMore();
    expect(repository.requests, hasLength(1));
  });
}

ProviderContainer _container(_Repository repository) =>
    ProviderContainer(overrides: [
      currentAccountIdProvider.overrideWithValue('A'),
      currentAccountReaderProvider.overrideWithValue(() => 'A'),
      studyRepositoryProvider.overrideWithValue(repository),
    ]);

SavedQuizModel _session(String id) => SavedQuizModel(
      id: id,
      quizType: 'VOCABULARY',
      jlptLevel: 'N5',
      mode: 'normal',
      totalQuestions: 10,
      answeredCount: 2,
      remainingCount: 8,
      startedAt: '2026-10-01T00:00:00Z',
      resumeStatus: 'available',
    );

class _Repository extends Fake implements StudyRepository {
  final requests = <Completer<SavedQuizPageModel>>[];
  final cursors = <String?>[];
  @override
  Future<SavedQuizPageModel> fetchIncompleteQuizzes(
      {int limit = 20, String? cursor, String? quizType, String? jlptLevel}) {
    expect(quizType, isNull);
    expect(jlptLevel, isNull);
    cursors.add(cursor);
    final request = Completer<SavedQuizPageModel>();
    requests.add(request);
    return request.future;
  }
}
