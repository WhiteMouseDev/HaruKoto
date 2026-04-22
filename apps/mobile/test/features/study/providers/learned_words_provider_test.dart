import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/word_entry_model.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/providers/learned_words_provider.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';

void main() {
  group('LearnedWordsController', () {
    test('refresh loads entries and summary from the repository', () async {
      final repository = _FakeStudyRepository();
      final container = _buildContainer(repository);
      final sub = container.listen(learnedWordsProvider, (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      await container.read(learnedWordsProvider.notifier).refresh();

      final state = container.read(learnedWordsProvider);
      expect(repository.fetchCalls, 1);
      expect(repository.lastPage, 1);
      expect(repository.lastSort, 'recent');
      expect(repository.lastSearch, '');
      expect(repository.lastFilter, 'ALL');
      expect(state.loading, isFalse);
      expect(state.entries, repository.entries);
      expect(state.summary, repository.summary);
      expect(state.totalPages, 3);
    });

    test('search sort and filter changes reset pagination and expansion',
        () async {
      final repository = _FakeStudyRepository();
      final container = _buildContainer(repository);
      final sub = container.listen(learnedWordsProvider, (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      final notifier = container.read(learnedWordsProvider.notifier);
      await notifier.refresh();
      await notifier.nextPage();
      notifier.toggleExpanded('learned-1');
      await notifier.changeSearch('食べる');
      await notifier.changeSort('alphabetical');
      await notifier.changeFilter('MASTERED');

      final state = container.read(learnedWordsProvider);
      expect(repository.fetchCalls, 5);
      expect(state.page, 1);
      expect(state.search, '食べる');
      expect(state.sort, 'alphabetical');
      expect(state.filter, 'MASTERED');
      expect(state.expandedId, isNull);
      expect(repository.lastPage, 1);
      expect(repository.lastSearch, '食べる');
      expect(repository.lastSort, 'alphabetical');
      expect(repository.lastFilter, 'MASTERED');
    });

    test('pagination loads previous and next pages within bounds', () async {
      final repository = _FakeStudyRepository();
      final container = _buildContainer(repository);
      final sub = container.listen(learnedWordsProvider, (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      final notifier = container.read(learnedWordsProvider.notifier);
      await notifier.refresh();
      await notifier.previousPage();
      expect(container.read(learnedWordsProvider).page, 1);
      expect(repository.fetchCalls, 1);

      await notifier.nextPage();
      expect(container.read(learnedWordsProvider).page, 2);
      expect(repository.lastPage, 2);

      await notifier.nextPage();
      await notifier.nextPage();
      expect(container.read(learnedWordsProvider).page, 3);
      expect(repository.fetchCalls, 3);
    });

    test('toggleExpanded opens and closes the selected word card', () {
      final repository = _FakeStudyRepository();
      final container = _buildContainer(repository);
      final sub = container.listen(learnedWordsProvider, (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      final notifier = container.read(learnedWordsProvider.notifier);
      notifier.toggleExpanded('learned-1');
      expect(container.read(learnedWordsProvider).expandedId, 'learned-1');

      notifier.toggleExpanded('learned-1');
      expect(container.read(learnedWordsProvider).expandedId, isNull);
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
    LearnedWordModel(
      id: 'learned-1',
      vocabularyId: 'vocab-1',
      word: '食べる',
      reading: 'たべる',
      meaningKo: '먹다',
      jlptLevel: 'N5',
      correctCount: 3,
      incorrectCount: 1,
      streak: 2,
      mastered: false,
    ),
  ];
  final summary = const LearnedWordsSummary(
    totalLearned: 12,
    mastered: 4,
    learning: 8,
  );

  int fetchCalls = 0;
  int? lastPage;
  String? lastSort;
  String? lastSearch;
  String? lastFilter;

  @override
  Future<
      ({
        List<LearnedWordModel> entries,
        int total,
        int totalPages,
        LearnedWordsSummary summary,
      })> fetchLearnedWords({
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
      summary: summary,
    );
  }
}
