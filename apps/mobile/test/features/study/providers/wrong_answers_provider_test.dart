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
      expect(state.totalPages, 3);
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
  String? lastAddedWord;
  String? lastAddedSource;

  @override
  Future<
      ({
        List<WrongEntryModel> entries,
        int total,
        int totalPages,
        WrongAnswersSummary summary,
      })> fetchWrongAnswers({
    int page = 1,
    String sort = 'most-wrong',
    int limit = 20,
  }) async {
    fetchCalls++;
    lastPage = page;
    lastSort = sort;
    return (
      entries: entries,
      total: entries.length,
      totalPages: 3,
      summary: summary,
    );
  }

  @override
  Future<void> addWord({
    required String word,
    required String reading,
    required String meaningKo,
    String source = 'MANUAL',
    String? note,
  }) async {
    addWordCalls++;
    lastAddedWord = word;
    lastAddedSource = source;
  }
}
