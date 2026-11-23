import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_question_model.dart';
import 'package:harukoto_mobile/features/study/data/models/saved_quiz_model.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/presentation/quiz_page.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/saved_quiz_section.dart';
import 'package:harukoto_mobile/features/study/providers/quiz_session_provider.dart';
import 'package:harukoto_mobile/features/study/providers/saved_quiz_provider.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('home shows just one latest-start card and all opens every level',
      (tester) async {
    await _pump(tester, [
      _session('newest', 'N4'),
      _session('older', 'N5'),
      _session('oldest', 'N3'),
    ]);
    expect(find.text('최근 시작한 퀴즈'), findsOneWidget);
    expect(find.byKey(const ValueKey('saved-quiz-newest')), findsOneWidget);
    expect(find.byKey(const ValueKey('saved-quiz-older')), findsNothing);
    await tester.tap(find.text('전체 보기'));
    await tester.pumpAndSettle();
    expect(find.text('모든 레벨 · 최근 시작 순'), findsOneWidget);
    expect(find.byKey(const ValueKey('saved-quiz-newest')), findsOneWidget);
    expect(find.byKey(const ValueKey('saved-quiz-older')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unavailable representative cannot hide older resumable sessions',
      (tester) async {
    await _pump(tester, [
      _session('invalid', 'N5', status: 'invalid_snapshot'),
      _session('good', 'N5'),
    ]);
    expect(find.text('저장 기록 안내'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.tap(find.text('전체 보기'));
    await tester.pumpAndSettle();
    expect(find.text('이어서 풀기'), findsOneWidget);
    expect(find.byKey(const ValueKey('saved-quiz-good')), findsOneWidget);
  });

  testWidgets('the Home saved quiz resumes the same session and next question',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final saved = _session('original-session', 'N4');
    final repository = _ResumeRepository(saved);
    final container = ProviderContainer(overrides: [
      currentAccountIdProvider.overrideWithValue('A'),
      currentAccountReaderProvider.overrideWithValue(() => 'A'),
      sharedPreferencesProvider.overrideWithValue(preferences),
      studyRepositoryProvider.overrideWithValue(repository),
    ]);

    try {
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SavedQuizSection())),
      ));
      await tester.pumpAndSettle();
      final resume = find.descendant(
        of: find.byKey(ValueKey('saved-quiz-${saved.id}')),
        matching: find.text('이어서 풀기'),
      );
      await tester.tap(resume);
      await tester.pumpAndSettle();

      final page = tester.widget<QuizPage>(find.byType(QuizPage));
      expect(page.resumeSessionId, saved.id);
      expect(page.jlptLevel, saved.jlptLevel);
      expect(repository.resumedSessionIds, [saved.id]);
      expect(repository.newQuizStarts, 0);
      final resumed = container.read(quizSessionProvider);
      expect(resumed.sessionId, saved.id);
      expect(resumed.currentIndex, saved.answeredCount);
      expect(resumed.currentQuestion?.questionId, 'q3');
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 1));
      container.dispose();
    }
  });

  testWidgets('all answered explicitly offers result recovery, not a new start',
      (tester) async {
    await _pump(tester, [_session('all-saved', 'N5', answered: 10)]);
    expect(find.text('10/10문제 저장됨'), findsOneWidget);
    expect(find.text('결과 확인하기'), findsOneWidget);
    expect(find.text('새로 시작하기'), findsNothing);
  });

  testWidgets('empty representative still exposes the global list',
      (tester) async {
    await _pump(tester, []);
    expect(find.text('전체 보기'), findsOneWidget);
    await tester.tap(find.text('전체 보기'));
    await tester.pumpAndSettle();
    expect(find.text('아직 저장된 퀴즈가 없어요.'), findsOneWidget);
  });

  testWidgets('large text and narrow width do not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(tester, [_session('narrow', 'N5')], scale: 2);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(WidgetTester tester, List<SavedQuizModel> sessions,
    {double scale = 1}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentAccountIdProvider.overrideWithValue('A'),
      currentAccountReaderProvider.overrideWithValue(() => 'A'),
      savedQuizListProvider.overrideWith(() => _List(sessions)),
    ],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const Scaffold(
          body: SingleChildScrollView(
        child: Padding(padding: EdgeInsets.all(20), child: SavedQuizSection()),
      )),
    ),
  ));
  await tester.pumpAndSettle();
}

class _List extends SavedQuizList {
  _List(this.sessions);
  final List<SavedQuizModel> sessions;
  @override
  Future<SavedQuizListState> build() async =>
      SavedQuizListState(accountId: 'A', sessions: sessions);
}

class _ResumeRepository extends Fake implements StudyRepository {
  _ResumeRepository(this.saved);

  final SavedQuizModel saved;
  final resumedSessionIds = <String>[];
  int newQuizStarts = 0;

  @override
  Future<SavedQuizPageModel> fetchIncompleteQuizzes({
    int limit = 20,
    String? cursor,
    String? quizType,
    String? jlptLevel,
  }) async =>
      SavedQuizPageModel(sessions: [saved]);

  @override
  Future<
      ({
        String sessionId,
        List<QuizQuestionModel> questions,
        List<String> answeredQuestionIds,
        int correctCount,
        String? quizType,
        String? mode,
      })> resumeQuiz(String sessionId) async {
    resumedSessionIds.add(sessionId);
    final questions = List.generate(
      saved.totalQuestions,
      (index) => QuizQuestionModel(
        questionId: 'q${index + 1}',
        questionText: '문제 ${index + 1}',
        options: const [QuizOption(id: 'correct', text: '정답')],
        correctOptionId: 'correct',
      ),
    );
    return (
      sessionId: saved.id,
      questions: questions,
      answeredQuestionIds: questions
          .take(saved.answeredCount)
          .map((question) => question.questionId)
          .toList(),
      correctCount: saved.answeredCount,
      quizType: saved.quizType,
      mode: saved.mode,
    );
  }

  @override
  Future<({String sessionId, List<QuizQuestionModel> questions, String? mode})>
      startQuiz({
    required String quizType,
    required String jlptLevel,
    required int count,
    String? mode,
    String? stageId,
  }) async {
    newQuizStarts++;
    throw StateError('The Home saved quiz must resume its existing session.');
  }
}

SavedQuizModel _session(String id, String level,
        {String status = 'available', int answered = 2}) =>
    SavedQuizModel(
      id: id,
      quizType: 'VOCABULARY',
      jlptLevel: level,
      mode: 'normal',
      totalQuestions: 10,
      answeredCount: answered,
      remainingCount: status == 'available' ? 10 - answered : null,
      startedAt: '2026-10-01T00:00:00Z',
      resumeStatus: status,
    );
