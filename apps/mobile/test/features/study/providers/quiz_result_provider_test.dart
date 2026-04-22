import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_result_model.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/providers/quiz_result_provider.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';

void main() {
  group('QuizResultController', () {
    test('loadWrongAnswers skips repository when there are no wrong answers',
        () async {
      final repository = _FakeStudyRepository();
      final container = _buildContainer(repository);
      final sub = container.listen(quizResultProvider, (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      await container.read(quizResultProvider.notifier).loadWrongAnswers(
            sessionId: 'session-1',
            wrongCount: 0,
          );

      final state = container.read(quizResultProvider);
      expect(repository.fetchWrongAnswersCalls, 0);
      expect(state.loadingWrong, isFalse);
      expect(state.wrongAnswers, isEmpty);
    });

    test('loadWrongAnswers loads wrong answers from the repository', () async {
      final repository = _FakeStudyRepository();
      final container = _buildContainer(repository);
      final sub = container.listen(quizResultProvider, (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      await container.read(quizResultProvider.notifier).loadWrongAnswers(
            sessionId: 'session-1',
            wrongCount: 2,
          );

      final state = container.read(quizResultProvider);
      expect(repository.fetchWrongAnswersCalls, 1);
      expect(repository.lastSessionId, 'session-1');
      expect(state.loadingWrong, isFalse);
      expect(state.wrongAnswers, repository.wrongAnswers);
    });

    test('saveToWordbook persists once and marks the question as saved',
        () async {
      final repository = _FakeStudyRepository();
      final container = _buildContainer(repository);
      final sub = container.listen(quizResultProvider, (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      final notifier = container.read(quizResultProvider.notifier);
      final item = repository.wrongAnswers.first;

      final firstSaved = await notifier.saveToWordbook(item);
      final secondSaved = await notifier.saveToWordbook(item);

      final state = container.read(quizResultProvider);
      expect(firstSaved, isTrue);
      expect(secondSaved, isTrue);
      expect(repository.addWordCalls, 1);
      expect(repository.lastAddedWord, '食べる');
      expect(repository.lastAddedReading, 'たべる');
      expect(repository.lastAddedSource, 'QUIZ');
      expect(state.savedWords, contains('question-1'));
    });

    test('saveAllToWordbook persists every unsaved wrong answer', () async {
      final repository = _FakeStudyRepository();
      final container = _buildContainer(repository);
      final sub = container.listen(quizResultProvider, (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      final notifier = container.read(quizResultProvider.notifier);
      await notifier.loadWrongAnswers(sessionId: 'session-1', wrongCount: 2);

      final saved = await notifier.saveAllToWordbook();
      final secondSaved = await notifier.saveAllToWordbook();

      final state = container.read(quizResultProvider);
      expect(saved, isTrue);
      expect(secondSaved, isTrue);
      expect(repository.addWordCalls, 2);
      expect(state.savedWords, containsAll(['question-1', 'question-2']));
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
  final wrongAnswers = const [
    WrongAnswerModel(
      questionId: 'question-1',
      word: '食べる',
      reading: 'たべる',
      meaningKo: '먹다',
    ),
    WrongAnswerModel(
      questionId: 'question-2',
      word: '学校',
      meaningKo: '학교',
    ),
  ];

  int fetchWrongAnswersCalls = 0;
  int addWordCalls = 0;
  String? lastSessionId;
  String? lastAddedWord;
  String? lastAddedReading;
  String? lastAddedSource;

  @override
  Future<List<WrongAnswerModel>> fetchWrongAnswersBySession(
    String sessionId,
  ) async {
    fetchWrongAnswersCalls++;
    lastSessionId = sessionId;
    return wrongAnswers;
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
    lastAddedReading = reading;
    lastAddedSource = source;
  }
}
