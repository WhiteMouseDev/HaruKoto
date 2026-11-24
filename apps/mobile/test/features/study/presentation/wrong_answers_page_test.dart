import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harukoto_mobile/core/theme/app_theme.dart';
import 'package:harukoto_mobile/features/study/data/models/word_entry_model.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/presentation/wrong_answers_page.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';

void main() {
  testWidgets('wrong answer list sorts, expands and saves through real actions',
      (tester) async {
    final repository = _WrongAnswersRepository();
    await _pumpPage(tester, repository);

    expect(find.text('오답노트'), findsOneWidget);
    expect(find.text('전체 통계'), findsOneWidget);
    expect(find.text('오답 복습 퀴즈 시작'), findsOneWidget);
    expect(find.text('食べる'), findsOneWidget);
    expect(find.text('食べ物を食べる。'), findsNothing);

    await tester.tap(find.text('많이 틀린 순'));
    await tester.pumpAndSettle();
    expect(find.text('가나다 순'), findsOneWidget);
    await tester.tap(find.text('최근 순'));
    await tester.pumpAndSettle();
    expect(repository.sorts, ['most-wrong', 'recent']);

    await tester.tap(find.text('食べる'));
    await tester.pumpAndSettle();
    expect(find.text('食べ物を食べる。'), findsOneWidget);
    expect(find.text('음식을 먹다.'), findsOneWidget);
    expect(find.text('정답률'), findsOneWidget);

    final save = find.widgetWithText(OutlinedButton, '단어장에 추가');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, '저장 중'),
          )
          .onPressed,
      isNull,
    );
    repository.saveGate.complete();
    await tester.pumpAndSettle();
    expect(repository.saved, [('食べる', 'QUIZ')]);
    expect(find.text('단어장에 추가됨'), findsOneWidget);

    await tester.tap(find.text('食べる'));
    await tester.pumpAndSettle();
    expect(find.text('食べ物を食べる。'), findsNothing);
  });

  testWidgets('an initial failure has a real retry and recovers',
      (tester) async {
    final repository = _WrongAnswersRepository(failFirst: true);
    await _pumpPage(tester, repository);

    expect(find.text('오답노트를 불러올 수 없습니다.'), findsOneWidget);
    expect(find.text('오답노트 내역이 없어요.'), findsNothing);
    expect(find.text('다시 시도하기'), findsOneWidget);
    await tester.tap(find.text('다시 시도하기'));
    await tester.pumpAndSettle();
    expect(repository.sorts, ['most-wrong', 'most-wrong']);
    expect(find.text('食べる'), findsOneWidget);
  });

  testWidgets('empty action opens the Study route', (tester) async {
    final router = GoRouter(
      initialLocation: '/study/wrong-answers',
      routes: [
        GoRoute(
          path: '/study',
          builder: (_, __) => const Scaffold(body: Text('학습 탭 도착')),
          routes: [
            GoRoute(
              path: 'wrong-answers',
              builder: (_, __) => const WrongAnswersPage(),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        studyRepositoryProvider.overrideWithValue(
          _WrongAnswersRepository(entries: const []),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    expect(find.text('오답노트 내역이 없어요.'), findsOneWidget);
    expect(find.text('학습을 시작해 보세요!'), findsOneWidget);
    expect(find.text('전체 통계'), findsNothing);
    await tester.tap(find.text('학습 시작'));
    await tester.pumpAndSettle();
    expect(find.text('학습 탭 도착'), findsOneWidget);
  });

  testWidgets('loading and expanded cards fit narrow dark mode and large type',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final gate = Completer<void>();
    await _pumpPage(
      tester,
      _WrongAnswersRepository(readGate: gate),
      textScale: 2,
    );
    expect(find.text('전체 통계'), findsOneWidget);
    expect(find.text('食べる'), findsNothing);
    expect(
      find.byWidgetPredicate((widget) =>
          widget is Semantics && widget.properties.label == '오답 목록을 불러오는 중'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    gate.complete();
    await tester.pumpAndSettle();
    final word = find.text('食べる');
    await tester.scrollUntilVisible(word, 80);
    await tester.tap(word);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('단어장에 추가'), 80);
    expect(find.text('단어장에 추가'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  _WrongAnswersRepository repository, {
  double textScale = 1,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [studyRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      theme: textScale == 1 ? AppTheme.light : AppTheme.dark,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: const WrongAnswersPage(),
    ),
  ));
  await tester.pumpAndSettle();
}

class _WrongAnswersRepository extends Fake implements StudyRepository {
  _WrongAnswersRepository({
    this.entries = const [_entry],
    this.failFirst = false,
    this.readGate,
  });

  final List<WrongEntryModel> entries;
  final bool failFirst;
  final Completer<void>? readGate;
  final saveGate = Completer<void>();
  final sorts = <String>[];
  final saved = <(String, String)>[];

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
    sorts.add(sort);
    if (failFirst && sorts.length == 1) throw StateError('offline');
    if (readGate case final gate?) await gate.future;
    return (
      entries: entries,
      total: entries.length,
      totalPages: 1,
      summary: WrongAnswersSummary(
        totalWrong: entries.length,
        mastered: 0,
        remaining: entries.length,
      ),
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
    saved.add((word, source));
    await saveGate.future;
  }
}

const _entry = WrongEntryModel(
  id: 'wrong-one',
  vocabularyId: 'vocab-one',
  word: '食べる',
  reading: 'たべる',
  meaningKo: '먹다',
  jlptLevel: 'N5',
  exampleSentence: '食べ物を食べる。',
  exampleTranslation: '음식을 먹다.',
  correctCount: 2,
  incorrectCount: 3,
  mastered: false,
);
