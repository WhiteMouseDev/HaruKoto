import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/word_entry_model.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';
import 'package:harukoto_mobile/features/study/providers/wrong_answers_provider.dart';

void main() {
  group('WrongAnswersController', () {
    test('refresh loads entries and summary from the repository', () async {
      final repository = _FakeStudyRepository();
      final container = _buildContainer(repository);
      final sub = container.listen(wrongAnswersProvider, (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      await container.read(wrongAnswersProvider.notifier).refresh();

      final state = container.read(wrongAnswersProvider);
      expect(repository.fetchCalls, 1);
      expect(repository.lastPage, 1);
      expect(repository.lastSort, 'most-wrong');
      expect(state.loading, isFalse);
      expect(state.entries, repository.entries);
      expect(state.summary, repository.summary);
      expect(state.total, 10);
      expect(state.totalPages, 3);
      expect(state.supportsSearchAndStatus, isTrue);
    });

    test('sort changes reset pagination and expansion', () async {
      final repository = _FakeStudyRepository();
      final container = _buildContainer(repository);
      final sub = container.listen(wrongAnswersProvider, (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      final notifier = container.read(wrongAnswersProvider.notifier);
      await notifier.refresh();
      await notifier.nextPage();
      notifier.toggleExpanded('wrong-1');
      await notifier.changeSort('recent');

      final state = container.read(wrongAnswersProvider);
      expect(repository.fetchCalls, 3);
      expect(state.page, 1);
      expect(state.sort, 'recent');
      expect(state.expandedId, isNull);
      expect(repository.lastPage, 1);
      expect(repository.lastSort, 'recent');
    });

    test('pagination loads previous and next pages within bounds', () async {
      final repository = _FakeStudyRepository();
      final container = _buildContainer(repository);
      final sub = container.listen(wrongAnswersProvider, (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      final notifier = container.read(wrongAnswersProvider.notifier);
      await notifier.refresh();
      await notifier.previousPage();
      expect(container.read(wrongAnswersProvider).page, 1);
      expect(repository.fetchCalls, 1);

      await notifier.nextPage();
      expect(container.read(wrongAnswersProvider).page, 2);
      expect(repository.lastPage, 2);

      await notifier.nextPage();
      await notifier.nextPage();
      expect(container.read(wrongAnswersProvider).page, 3);
      expect(repository.fetchCalls, 3);
    });

    testWidgets('search debounces and invalidates older reads immediately',
        (tester) async {
      final repository = _FakeStudyRepository();
      final container = _buildContainer(repository);
      final sub = container.listen(wrongAnswersProvider, (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);
      final notifier = container.read(wrongAnswersProvider.notifier);
      await notifier.refresh();
      await notifier.nextPage();
      notifier.toggleExpanded('wrong-1');

      final oldReadGate = Completer<void>();
      repository.nextReadGate = oldReadGate;
      final oldRead = notifier.refresh();
      notifier.changeSearch('た');
      oldReadGate.complete();
      await oldRead;
      expect(sub.read().loading, isTrue);
      expect(sub.read().page, 1);
      expect(sub.read().expandedId, isNull);
      expect(sub.read().summary, repository.summary);

      await tester.pump(const Duration(milliseconds: 220));
      notifier.changeSearch(' たべる ');
      await tester.pump(const Duration(milliseconds: 299));
      expect(repository.fetchCalls, 3);
      await tester.pump(const Duration(milliseconds: 1));
      expect(repository.fetchCalls, 4);
      expect(repository.lastSearch, ' たべる ');
      expect(repository.lastPage, 1);
      expect(sub.read().loading, isFalse);
      expect(sub.read().total, 1);
      expect(sub.read().summary?.totalWrong, 10);
      expect(sub.read().hasActiveFilters, isTrue);

      notifier.changeSearch('たべる');
      await tester.pump(const Duration(milliseconds: 300));
      expect(repository.fetchCalls, 4);
      expect(sub.read().search, 'たべる');
    });

    testWidgets('status applies pending search and clear preserves sort',
        (tester) async {
      final repository = _FakeStudyRepository();
      final container = _buildContainer(repository);
      final sub = container.listen(wrongAnswersProvider, (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);
      final notifier = container.read(wrongAnswersProvider.notifier);
      await notifier.refresh();
      await notifier.changeSort('recent');
      await notifier.nextPage();

      notifier.changeSearch('食');
      await notifier.changeStatus(WrongAnswerStatus.learning);
      expect(repository.fetchCalls, 4);
      expect(repository.lastPage, 1);
      expect(repository.lastSort, 'recent');
      expect(repository.lastSearch, '食');
      expect(repository.lastStatus, WrongAnswerStatus.learning);
      expect(sub.read().total, 1);
      await tester.pump(const Duration(milliseconds: 300));
      expect(repository.fetchCalls, 4);

      notifier.changeSearch('먹');
      await notifier.clearFilters();
      expect(repository.fetchCalls, 5);
      expect(repository.lastSort, 'recent');
      expect(repository.lastSearch, isEmpty);
      expect(repository.lastStatus, WrongAnswerStatus.all);
      expect(sub.read().total, 10);
      expect(sub.read().hasActiveFilters, isFalse);
      await tester.pump(const Duration(milliseconds: 300));
      expect(repository.fetchCalls, 5);
    });

    testWidgets('legacy responses keep list features but ignore filters',
        (tester) async {
      final repository = _FakeStudyRepository()
        ..supportsSearchAndStatus = false;
      final container = _buildContainer(repository);
      final sub = container.listen(wrongAnswersProvider, (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);
      final notifier = container.read(wrongAnswersProvider.notifier);
      await notifier.refresh();

      notifier.changeSearch('食べる');
      await notifier.changeStatus(WrongAnswerStatus.mastered);
      await tester.pump(const Duration(milliseconds: 300));
      expect(repository.fetchCalls, 1);
      expect(sub.read().supportsSearchAndStatus, isFalse);
      expect(sub.read().hasActiveFilters, isFalse);
      expect(sub.read().entries, repository.entries);

      await notifier.changeSort('recent');
      await notifier.nextPage();
      expect(repository.fetchCalls, 3);
      expect(repository.lastPage, 2);
      expect(repository.lastSort, 'recent');
    });

    testWidgets('dispose cancels queued searches and ignores late reads',
        (tester) async {
      final repository = _FakeStudyRepository();
      final container = _buildContainer(repository);
      final sub = container.listen(wrongAnswersProvider, (_, __) {});
      final notifier = container.read(wrongAnswersProvider.notifier);
      await notifier.refresh();

      final oldReadGate = Completer<void>();
      repository.nextReadGate = oldReadGate;
      final oldRead = notifier.refresh();
      notifier.changeSearch('たべる');
      sub.close();
      container.dispose();

      oldReadGate.complete();
      await oldRead;
      await tester.pump(const Duration(milliseconds: 300));
      expect(repository.fetchCalls, 2);
    });

    test('toggleExpanded opens and closes the selected wrong-answer card', () {
      final repository = _FakeStudyRepository();
      final container = _buildContainer(repository);
      final sub = container.listen(wrongAnswersProvider, (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      final notifier = container.read(wrongAnswersProvider.notifier);
      notifier.toggleExpanded('wrong-1');
      expect(container.read(wrongAnswersProvider).expandedId, 'wrong-1');

      notifier.toggleExpanded('wrong-1');
      expect(container.read(wrongAnswersProvider).expandedId, isNull);
    });

    test('saveToWordbook persists once and marks the vocabulary as saved',
        () async {
      final repository = _FakeStudyRepository();
      final container = _buildContainer(repository);
      final sub = container.listen(wrongAnswersProvider, (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      final notifier = container.read(wrongAnswersProvider.notifier);
      final entry = repository.entries.first;

      final firstSaved = await notifier.saveToWordbook(entry);
      final secondSaved = await notifier.saveToWordbook(entry);

      final state = container.read(wrongAnswersProvider);
      expect(firstSaved, isTrue);
      expect(secondSaved, isTrue);
      expect(repository.addWordCalls, 1);
      expect(repository.lastAddedWord, '食べる');
      expect(repository.lastAddedSource, 'QUIZ');
      expect(state.savedWords, contains('vocab-1'));
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
    WrongEntryModel(
      id: 'wrong-1',
      vocabularyId: 'vocab-1',
      word: '食べる',
      reading: 'たべる',
      meaningKo: '먹다',
      jlptLevel: 'N5',
      correctCount: 1,
      incorrectCount: 4,
      mastered: false,
    ),
  ];
  final summary = const WrongAnswersSummary(
    totalWrong: 10,
    mastered: 3,
    remaining: 7,
  );

  int fetchCalls = 0;
  int addWordCalls = 0;
  int? lastPage;
  String? lastSort;
  String? lastSearch;
  WrongAnswerStatus? lastStatus;
  bool supportsSearchAndStatus = true;
  Completer<void>? nextReadGate;
  String? lastAddedWord;
  String? lastAddedSource;

  @override
  Future<
      ({
        List<WrongEntryModel> entries,
        int total,
        int totalPages,
        WrongAnswersSummary summary,
        bool supportsSearchAndStatus,
      })> fetchWrongAnswers({
    int page = 1,
    String sort = 'most-wrong',
    String search = '',
    WrongAnswerStatus status = WrongAnswerStatus.all,
    int limit = 20,
  }) async {
    fetchCalls++;
    lastPage = page;
    lastSort = sort;
    lastSearch = search;
    lastStatus = status;
    final gate = nextReadGate;
    nextReadGate = null;
    if (gate != null) await gate.future;
    return (
      entries: entries,
      total: search.trim().isNotEmpty || status != WrongAnswerStatus.all
          ? 1
          : summary.totalWrong,
      totalPages: 3,
      summary: summary,
      supportsSearchAndStatus: supportsSearchAndStatus,
    );
  }

  @override
  Future<void> addWord({
    required String word,
    required String reading,
    required String meaningKo,
    String source = 'MANUAL',
    bool preserveExisting = false,
    String? note,
  }) async {
    addWordCalls++;
    lastAddedWord = word;
    lastAddedSource = source;
  }
}
