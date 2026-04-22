import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
      expect(state.totalPages, 3);
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
  });
}

ProviderContainer _buildContainer(_FakeStudyRepository repository) {
  return ProviderContainer(
    overrides: [
      studyRepositoryProvider.overrideWith((ref) => repository),
    ],
  );
}

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

  @override
  Future<
      ({
        List<WordbookEntryModel> entries,
        int total,
        int totalPages,
      })> fetchWordbook({
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
    return (
      entries: entries,
      total: entries.length,
      totalPages: 3,
    );
  }

  @override
  Future<void> deleteWord(String id) async {
    deleteCalls++;
    lastDeletedId = id;
  }
}
