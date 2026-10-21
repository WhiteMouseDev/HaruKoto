import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/network/api_exception.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_result_model.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/providers/quiz_result_provider.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';

void main() {
  group('QuizResultController', () {
    for (final returnToOriginal in [false, true]) {
      test(
          'pending bulk save stays in its source session family '
          '(returnToOriginal=$returnToOriginal)', () async {
        final repository = _FakeStudyRepository()
          ..wordSaveGate = Completer<void>();
        final container = _buildContainer(repository);
        final sub =
            container.listen(quizResultProvider('session-1'), (_, __) {});
        final otherSub =
            container.listen(quizResultProvider('session-b'), (_, __) {});
        addTearDown(sub.close);
        addTearDown(otherSub.close);
        addTearDown(container.dispose);
        final notifier =
            container.read(quizResultProvider('session-1').notifier);
        await notifier.loadWrongAnswers(wrongCount: 2);
        final save = notifier.saveAllToWordbook();
        await container
            .read(quizResultProvider('session-b').notifier)
            .loadWrongAnswers(wrongCount: 0);
        if (returnToOriginal) {
          await notifier.loadWrongAnswers(wrongCount: 2);
        }
        repository.wordSaveGate!.complete();
        expect(await save, isTrue);
        expect(repository.addWordCalls, 2);
        expect(container.read(quizResultProvider('session-1')).savedWords,
            hasLength(2));
        expect(container.read(quizResultProvider('session-b')).savedWords,
            isEmpty);
      });
    }

    test('pending bulk save stops safely when provider is disposed', () async {
      final repository = _FakeStudyRepository()
        ..wordSaveGate = Completer<void>();
      final container = _buildContainer(repository);
      final notifier = container.read(quizResultProvider('session-1').notifier);
      await notifier.loadWrongAnswers(wrongCount: 2);
      final save = notifier.saveAllToWordbook();
      container.dispose();
      repository.wordSaveGate!.complete();
      expect(await save, isFalse);
      expect(repository.addWordCalls, 1);
    });

    test('failed GET stays an error and retries the same session', () async {
      final repository = _FakeStudyRepository()..failedLoads = 1;
      final container = _buildContainer(repository);
      final sub = container.listen(quizResultProvider('session-1'), (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);
      final notifier = container.read(quizResultProvider('session-1').notifier);

      await notifier.loadWrongAnswers(wrongCount: 2);
      expect(container.read(quizResultProvider('session-1')).loadingWrong,
          isFalse);
      expect(
          container.read(quizResultProvider('session-1')).error, '로그인이 필요합니다.');
      expect(container.read(quizResultProvider('session-1')).wrongAnswers,
          isEmpty);

      await notifier.loadWrongAnswers(wrongCount: 2);
      expect(repository.loadedSessionIds, ['session-1', 'session-1']);
      expect(container.read(quizResultProvider('session-1')).error, isNull);
      expect(container.read(quizResultProvider('session-1')).wrongAnswers,
          hasLength(2));
    });

    test('session families keep their lists and saved markers separate',
        () async {
      final repository = _FakeStudyRepository();
      final container = _buildContainer(repository);
      final sub = container.listen(quizResultProvider('session-1'), (_, __) {});
      final otherSub =
          container.listen(quizResultProvider('session-b'), (_, __) {});
      addTearDown(sub.close);
      addTearDown(otherSub.close);
      addTearDown(container.dispose);
      final notifier = container.read(quizResultProvider('session-1').notifier);
      await notifier.loadWrongAnswers(wrongCount: 2);
      await notifier.saveToWordbook(repository.wrongAnswers.first);
      repository.loadGates['session-b'] = Completer<List<WrongAnswerModel>>();

      final pending = container
          .read(quizResultProvider('session-b').notifier)
          .loadWrongAnswers(wrongCount: 1);
      final loading = container.read(quizResultProvider('session-b'));
      expect(loading.sessionId, 'session-b');
      expect(loading.loadingWrong, isTrue);
      expect(loading.wrongAnswers, isEmpty);
      expect(loading.savedWords, isEmpty);
      repository.loadGates['session-b']!
          .complete([repository.wrongAnswers.last]);
      await pending;
      expect(container.read(quizResultProvider('session-b')).wrongAnswers,
          [repository.wrongAnswers.last]);
      expect(container.read(quizResultProvider('session-1')).wrongAnswers,
          repository.wrongAnswers);
      expect(container.read(quizResultProvider('session-1')).savedWords,
          contains('question-1'));
    });

    test('late response from an earlier load cannot replace newer empty result',
        () async {
      final repository = _FakeStudyRepository();
      repository.loadGates['session-1'] = Completer<List<WrongAnswerModel>>();
      final container = _buildContainer(repository);
      final sub = container.listen(quizResultProvider('session-1'), (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);
      final notifier = container.read(quizResultProvider('session-1').notifier);
      final first = notifier.loadWrongAnswers(wrongCount: 2);
      await notifier.loadWrongAnswers(wrongCount: 0);
      repository.loadGates['session-1']!.complete(repository.wrongAnswers);
      await first;
      expect(container.read(quizResultProvider('session-1')).sessionId,
          'session-1');
      expect(container.read(quizResultProvider('session-1')).wrongAnswers,
          isEmpty);
      expect(container.read(quizResultProvider('session-1')).error, isNull);
    });

    test('a pending request can finish after the provider is disposed',
        () async {
      final repository = _FakeStudyRepository();
      repository.loadGates['session-1'] = Completer<List<WrongAnswerModel>>();
      final container = _buildContainer(repository);
      final pending = container
          .read(quizResultProvider('session-1').notifier)
          .loadWrongAnswers(wrongCount: 2);
      container.dispose();
      repository.loadGates['session-1']!.complete(repository.wrongAnswers);
      await expectLater(pending, completes);
    });

    test('loadWrongAnswers skips repository when there are no wrong answers',
        () async {
      final repository = _FakeStudyRepository();
      final container = _buildContainer(repository);
      final sub = container.listen(quizResultProvider('session-1'), (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      await container
          .read(quizResultProvider('session-1').notifier)
          .loadWrongAnswers(
            wrongCount: 0,
          );

      final state = container.read(quizResultProvider('session-1'));
      expect(repository.fetchWrongAnswersCalls, 0);
      expect(state.loadingWrong, isFalse);
      expect(state.wrongAnswers, isEmpty);
    });

    test('loadWrongAnswers loads wrong answers from the repository', () async {
      final repository = _FakeStudyRepository();
      final container = _buildContainer(repository);
      final sub = container.listen(quizResultProvider('session-1'), (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      await container
          .read(quizResultProvider('session-1').notifier)
          .loadWrongAnswers(
            wrongCount: 2,
          );

      final state = container.read(quizResultProvider('session-1'));
      expect(repository.fetchWrongAnswersCalls, 1);
      expect(repository.lastSessionId, 'session-1');
      expect(state.loadingWrong, isFalse);
      expect(state.wrongAnswers, repository.wrongAnswers);
    });

    test('saveToWordbook persists once and marks the question as saved',
        () async {
      final repository = _FakeStudyRepository();
      final container = _buildContainer(repository);
      final sub = container.listen(quizResultProvider('session-1'), (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      final notifier = container.read(quizResultProvider('session-1').notifier);
      final item = repository.wrongAnswers.first;

      final firstSaved = await notifier.saveToWordbook(item);
      final secondSaved = await notifier.saveToWordbook(item);

      final state = container.read(quizResultProvider('session-1'));
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
      final sub = container.listen(quizResultProvider('session-1'), (_, __) {});
      addTearDown(sub.close);
      addTearDown(container.dispose);

      final notifier = container.read(quizResultProvider('session-1').notifier);
      await notifier.loadWrongAnswers(wrongCount: 2);

      final saved = await notifier.saveAllToWordbook();
      final secondSaved = await notifier.saveAllToWordbook();

      final state = container.read(quizResultProvider('session-1'));
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
  int failedLoads = 0;
  Completer<void>? wordSaveGate;
  final loadedSessionIds = <String>[];
  final loadGates = <String, Completer<List<WrongAnswerModel>>>{};
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
    loadedSessionIds.add(sessionId);
    if (failedLoads > 0) {
      failedLoads--;
      throw const ApiException(message: 'private details', statusCode: 401);
    }
    final gate = loadGates[sessionId];
    if (gate != null) return gate.future;
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
    await wordSaveGate?.future;
  }
}
