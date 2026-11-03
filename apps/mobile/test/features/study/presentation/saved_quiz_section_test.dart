import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/features/study/data/models/saved_quiz_model.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/saved_quiz_section.dart';
import 'package:harukoto_mobile/features/study/providers/saved_quiz_provider.dart';

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
