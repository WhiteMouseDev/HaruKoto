import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/features/study/data/models/wordbook_entry_model.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';
import 'package:harukoto_mobile/features/study/providers/wordbook_provider.dart';

void main() {
  group('WordbookController', () {
    test('refresh loads the current page from the repository', () async {
      final repository = _FakeStudyRepository();
      final container = _buildContainer(repository);
      final sub = container.listen(wordbookProvider, (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      await container.read(wordbookProvider.notifier).refresh();

      final state = container.read(wordbookProvider);
      expect(repository.fetchCalls, 1);
      expect(repository.lastPage, 1);
      expect(repository.lastSort, 'recent');
      expect(repository.lastSearch, '');
      expect(repository.lastFilter, 'ALL');
      expect(state.loading, isFalse);
      expect(state.entries, repository.entries);
      expect(state.total, 52);
      expect(state.totalPages, 3);
    });

    test('changing sort keeps the active query and returns to page one',
        () async {
      final repository = _FakeStudyRepository();
      final container = _buildContainer(repository);
      final sub = container.listen(wordbookProvider, (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      final notifier = container.read(wordbookProvider.notifier);
      await notifier.changeSearch('食べ');
      await notifier.changeFilter('QUIZ');
      await notifier.nextPage();
      await notifier.changeSort('most-wrong', search: '食べる');
      await notifier.changeSort('most-wrong');

      expect(repository.fetchCalls, 4);
      expect(repository.lastPage, 1);
      expect(repository.lastSort, 'most-wrong');
      expect(repository.lastSearch, '食べる');
      expect(repository.lastFilter, 'QUIZ');
    });

    test('search and filter changes reset pagination before loading', () async {
      final repository = _FakeStudyRepository();
      final container = _buildContainer(repository);
      final sub = container.listen(wordbookProvider, (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      final notifier = container.read(wordbookProvider.notifier);
      await notifier.refresh();
      await notifier.nextPage();
      await notifier.changeSearch('食べる');
      await notifier.changeFilter('QUIZ');

      final state = container.read(wordbookProvider);
      expect(repository.fetchCalls, 4);
      expect(state.page, 1);
      expect(state.search, '食べる');
      expect(state.filter, 'QUIZ');
      expect(repository.lastPage, 1);
      expect(repository.lastSearch, '食べる');
      expect(repository.lastFilter, 'QUIZ');
    });

    test('pagination loads previous and next pages within bounds', () async {
      final repository = _FakeStudyRepository();
      final container = _buildContainer(repository);
      final sub = container.listen(wordbookProvider, (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      final notifier = container.read(wordbookProvider.notifier);
      await notifier.refresh();
      await notifier.previousPage();
      expect(container.read(wordbookProvider).page, 1);
      expect(repository.fetchCalls, 1);

      await notifier.nextPage();
      expect(container.read(wordbookProvider).page, 2);
      expect(repository.lastPage, 2);

      await notifier.nextPage();
      await notifier.nextPage();
      expect(container.read(wordbookProvider).page, 3);
      expect(repository.fetchCalls, 3);
    });

    test('delete refreshes the wordbook after repository success', () async {
      final repository = _FakeStudyRepository();
      final container = _buildContainer(repository);
      final sub = container.listen(wordbookProvider, (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      final notifier = container.read(wordbookProvider.notifier);
      await notifier.refresh();

      final deleted = await notifier.deleteWord('word-1');

      expect(deleted, isTrue);
      expect(repository.deleteCalls, 1);
      expect(repository.lastDeletedId, 'word-1');
      expect(repository.fetchCalls, 2);
    });

    test('a vanished result set returns to page one without a second fetch',
        () async {
      final repository = _FakeStudyRepository();
      final container = _buildContainer(repository);
      final sub = container.listen(wordbookProvider, (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      final notifier = container.read(wordbookProvider.notifier);
      await notifier.changeSearch('食べる');
      await notifier.nextPage();
      repository.load = (_, __) async => _emptyWordbook;
      await notifier.refresh();

      final state = container.read(wordbookProvider);
      expect(repository.fetchCalls, 3);
      expect(state.page, 1);
      expect(state.search, '食べる');
      expect(state.entries, isEmpty);
      expect(state.total, 0);
      expect(state.loading, isFalse);
    });

    test('a delayed fallback cannot overwrite the newer search', () async {
      final repository = _FakeStudyRepository();
      final container = _buildContainer(repository);
      final sub = container.listen(wordbookProvider, (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      final notifier = container.read(wordbookProvider.notifier);
      await notifier.changeSearch('食べ');
      await notifier.nextPage();
      final fallbackStarted = Completer<void>();
      final fallback = Completer<_WordbookResponse>();
      repository.load = (page, search) async {
        if (search == '新規') return _emptyWordbook;
        if (page == 2) return _pastLastPage;
        fallbackStarted.complete();
        return fallback.future;
      };

      final refreshing = notifier.refresh();
      await fallbackStarted.future;
      await notifier.changeSearch('新規');
      fallback
          .complete((entries: repository.entries, total: 20, totalPages: 1));
      await refreshing;

      final state = container.read(wordbookProvider);
      expect(state.search, '新規');
      expect(state.page, 1);
      expect(state.entries, isEmpty);
      expect(state.total, 0);
      expect(state.loading, isFalse);
    });

    test('empty rows on the reported last page fall back one page', () async {
      final repository = _FakeStudyRepository();
      final container = _buildContainer(repository);
      final sub = container.listen(wordbookProvider, (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      final notifier = container.read(wordbookProvider.notifier);
      await notifier.changeSearch('食べる');
      await notifier.nextPage();
      repository.load = (page, search) async {
        expect(search, '食べる');
        if (page == 2) {
          return (
            entries: <WordbookEntryModel>[],
            total: 21,
            totalPages: 2,
          );
        }
        return (entries: repository.entries, total: 20, totalPages: 1);
      };
      await notifier.refresh();

      final state = container.read(wordbookProvider);
      expect(repository.fetchCalls, 4);
      expect(repository.lastPage, 1);
      expect(state.page, 1);
      expect(state.totalPages, 1);
      expect(state.entries, repository.entries);
    });

    test('an old account response does not fetch a fallback page', () async {
      final repository = _FakeStudyRepository();
      var owner = 'old-owner';
      final container = _buildContainer(repository, accountReader: () => owner);
      final sub = container.listen(wordbookProvider, (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      final notifier = container.read(wordbookProvider.notifier);
      await notifier.changeSearch('食べ');
      await notifier.nextPage();
      final outOfRange = Completer<_WordbookResponse>();
      repository.load = (_, __) => outOfRange.future;
      final refreshing = notifier.refresh();
      owner = 'new-owner';
      outOfRange.complete(_pastLastPage);
      await refreshing;

      expect(repository.fetchCalls, 3);
      expect(repository.lastPage, 2);
    });

    test('an old account delete completion does not refresh the list',
        () async {
      final repository = _FakeStudyRepository();
      var owner = 'old-owner';
      final container = _buildContainer(repository, accountReader: () => owner);
      final sub = container.listen(wordbookProvider, (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      final notifier = container.read(wordbookProvider.notifier);
      await notifier.refresh();
      final pendingDelete = repository.pendingDelete = Completer<void>();
      final deleting = notifier.deleteWord('word-1');
      owner = 'new-owner';
      pendingDelete.complete();

      expect(await deleting, isFalse);
      expect(repository.fetchCalls, 1);
    });
  });
}

ProviderContainer _buildContainer(
  _FakeStudyRepository repository, {
  String? Function()? accountReader,
}) {
  return ProviderContainer(
    overrides: [
      currentAccountReaderProvider.overrideWithValue(
        accountReader ?? () => 'test-owner',
      ),
      studyRepositoryProvider.overrideWith((ref) => repository),
    ],
  );
}

typedef _WordbookResponse = ({
  List<WordbookEntryModel> entries,
  int total,
  int totalPages,
});

const _WordbookResponse _emptyWordbook = (entries: [], total: 0, totalPages: 0);
const _WordbookResponse _pastLastPage = (entries: [], total: 20, totalPages: 1);

class _FakeStudyRepository extends Fake implements StudyRepository {
  final entries = const [
    WordbookEntryModel(
      id: 'word-1',
      word: '食べる',
      reading: 'たべる',
      meaningKo: '먹다',
      source: 'MANUAL',
      createdAt: '2024-01-01T00:00:00Z',
    ),
  ];

  int fetchCalls = 0;
  int deleteCalls = 0;
  int? lastPage;
  String? lastSort;
  String? lastSearch;
  String? lastFilter;
  String? lastDeletedId;
  Future<_WordbookResponse> Function(int page, String search)? load;
  Completer<void>? pendingDelete;

  @override
  Future<_WordbookResponse> fetchWordbook({
    int page = 1,
    String sort = 'recent',
    String search = '',
    String filter = 'ALL',
    int limit = 20,
  }) async {
    fetchCalls++;
    lastPage = page;
    lastSort = sort;
    lastSearch = search;
    lastFilter = filter;
    if (load case final handler?) return handler(page, search);
    return (
      entries: entries,
      total: 52,
      totalPages: 3,
    );
  }

  @override
  Future<void> deleteWord(String id) async {
    deleteCalls++;
    lastDeletedId = id;
    await pendingDelete?.future;
  }
}
