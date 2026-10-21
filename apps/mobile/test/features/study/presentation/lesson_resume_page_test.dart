import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_sentence_reorder_step.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/presentation/lesson_page.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_recognition_check_step.dart';
import 'package:harukoto_mobile/features/study/providers/lesson_session_provider.dart';

import '../fixtures/lesson_resume_fixture.dart';

Future<void> _mount(WidgetTester tester, ResumeHarness h,
    {Size size = const Size(390, 844), double textScale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: h.container,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!),
        home: const LessonPage(lessonId: resumeLessonId),
      )));
  await tester.pumpAndSettle();
}

Future<GoRouter> _mountRouted(WidgetTester tester, ResumeHarness h) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = GoRouter(initialLocation: '/home', routes: [
    GoRoute(
        path: '/home',
        builder: (context, state) => Scaffold(
            body: Center(
                child: TextButton(
                    onPressed: () => context.push('/lesson'),
                    child: const Text('Open fixture lesson'))))),
    GoRoute(
        path: '/lesson',
        builder: (context, state) =>
            const LessonPage(lessonId: resumeLessonId)),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
      container: h.container, child: MaterialApp.router(routerConfig: router)));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open fixture lesson'));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets(
      'real page restores second recognition and selected option, then continues once',
      (tester) async {
    final before = ResumeHarness();
    await before.recognition();
    before.controller.answerRecognition(before.repository.detail,
        {'order': 2, 'selectedAnswer': 'b', 'responseMs': 0});
    before.controller.selectRecognition('c');
    await before.controller.flush();
    before.dispose();
    final h = ResumeHarness(store: before.store);
    addTearDown(h.dispose);
    await _mount(tester, h);
    expect(find.text('문항 2/2'), findsOneWidget);
    expect(find.text('확인했어요'), findsOneWidget);
    expect(h.repository.fetchCalls, 1);
    expect(h.repository.startCalls, 0);
    expect(h.repository.submitCalls, 0);
    await tester.tap(find.text('다음으로'));
    await tester.pumpAndSettle();
    expect(find.text('단어 매칭'), findsOneWidget);
    expect(h.state.answers[7]?['selectedAnswer'], 'c');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'all-matched restore never auto-submits and uses explicit continue',
      (tester) async {
    final before = ResumeHarness(
        repository:
            ResumeStudyRepository(detail: resumeDetail(withReorder: false)));
    await before.matching();
    before.controller.updateMatching(matched: {0, 1, 2});
    await before.controller.flush();
    before.dispose();
    final h = ResumeHarness(
        store: before.store,
        repository: ResumeStudyRepository(detail: before.repository.detail));
    addTearDown(h.dispose);
    await _mount(tester, h);
    await tester.pump(const Duration(seconds: 1));
    expect(h.repository.submitCalls, 0);
    expect(find.text('계속하기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'real old-account widget answer closure cannot change a new same-phase account',
      (tester) async {
    final h = ResumeHarness();
    addTearDown(h.dispose);
    await h.recognition();
    await _mount(tester, h);
    final oldWidget = tester.widget<LessonRecognitionCheckStep>(
        find.byType(LessonRecognitionCheckStep));
    final oldAnswer = oldWidget.onAnswer;
    h.account = 'account-b';
    h.container.invalidate(currentAccountIdProvider);
    await tester.pump();
    await tester.pumpAndSettle();
    await h.controller.startPractice(h.repository.detail);
    await tester.pumpAndSettle();
    await h.controller.flush();
    expect(h.state.step, LessonStep.recognition);
    final before = Map<String, String>.from(h.store.values);
    oldAnswer({'order': 2, 'selectedAnswer': 'a', 'responseMs': 0});
    await tester.pumpAndSettle();
    expect(h.state.answers, isEmpty);
    expect(h.state.recognitionIndex, 0);
    expect(h.store.values, before);
    expect(h.repository.submitCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'unknown response has only read-only check; newer server score replaces old score',
      (tester) async {
    final repo =
        ResumeStudyRepository(detail: resumeDetail(progress: completedProgress))
          ..submitError = TimeoutException('lost');
    final h = ResumeHarness(repository: repo);
    addTearDown(h.dispose);
    await h.recognition();
    await h.controller.submitAnswers(lessonId: resumeLessonId, jlptLevel: 'N5');
    await _mount(tester, h);
    expect(find.text('서버 기록 다시 확인'), findsOneWidget);
    expect(find.text('답안 제출하기'), findsNothing);
    repo.detail = resumeDetail(
        progress: const LessonProgressModel(
            status: 'COMPLETED',
            attempts: 2,
            scoreCorrect: 4,
            scoreTotal: 4,
            startedAt: '2026-10-21T01:00:00Z',
            completedAt: '2026-10-21T03:00:00Z'));
    await tester.tap(find.text('서버 기록 다시 확인'));
    await tester.pumpAndSettle();
    expect(find.text('저장된 레슨 기록 · 4/4문항'), findsOneWidget);
    expect(find.text('저장된 레슨 기록 · 2/4문항'), findsNothing);
    expect(repo.submitCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('storage failure is visible and retry saves latest state',
      (tester) async {
    final h = ResumeHarness();
    addTearDown(h.dispose);
    await h.recognition();
    await _mount(tester, h);
    h.store.failWrite = true;
    h.controller.selectRecognition('b');
    await tester.pumpAndSettle();
    expect(find.text('최근 진행이 기기에 저장되지 않았어요.'), findsOneWidget);
    h.store.failWrite = false;
    await tester.tap(find.text('저장 재시도'));
    await tester.pumpAndSettle();
    expect(find.text('최근 진행이 기기에 저장되지 않았어요.'), findsNothing);
    expect(
        h.store.values.values.single, contains('"recognitionSelection":"b"'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('new pending/check UI wraps at 320 width and 200 percent text',
      (tester) async {
    final h = ResumeHarness();
    addTearDown(h.dispose);
    await h.recognition();
    h.repository.submitError = TimeoutException('lost');
    await h.controller.submitAnswers(lessonId: resumeLessonId, jlptLevel: 'N5');
    await _mount(tester, h, size: const Size(320, 844), textScale: 2);
    expect(find.text('서버 기록 다시 확인'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'close freezes delayed answers and system back until durable save finishes',
      (tester) async {
    final h = ResumeHarness();
    addTearDown(h.dispose);
    await h.reorder();
    final bank = List<String>.from(h.state.layout.reorderBanks[11]!)
      ..remove('は');
    h.controller.updateReorder(selected: ['は'], available: bank);
    await h.controller.flush();
    await _mountRouted(tester, h);
    final oldAnswer = tester
        .widget<LessonSentenceReorderStep>(
            find.byType(LessonSentenceReorderStep))
        .onAnswer;
    h.store.writeGate = Completer<void>();
    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pump();
    oldAnswer({
      'order': 11,
      'submittedOrder': ['は', 'は', 'です'],
      'responseMs': 0
    });
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(LessonPage), findsOneWidget);
    expect(h.state.reorderIndex, 0);
    expect(h.repository.submitCalls, 0);
    h.store.writeGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(LessonPage), findsNothing);
    expect(find.text('Open fixture lesson'), findsOneWidget);
    expect(h.store.values.values.single, contains('"reorderIndex":0'));
    expect(h.store.values.values.single, contains('"reorderSelected":["は"]'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'failed close stays on page until user chooses and restores editing on stay',
      (tester) async {
    final h = ResumeHarness();
    addTearDown(h.dispose);
    await h.reorder();
    await _mountRouted(tester, h);
    h.store.failWrite = true;
    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pumpAndSettle();
    expect(find.text('최근 진행을 저장하지 못했어요'), findsOneWidget);
    expect(find.byType(LessonPage), findsOneWidget);
    await tester.tap(find.text('머무르기'));
    await tester.pumpAndSettle();
    h.store.failWrite = false;
    final answer = tester
        .widget<LessonSentenceReorderStep>(
            find.byType(LessonSentenceReorderStep))
        .onAnswer;
    answer({
      'order': 11,
      'submittedOrder': ['は', 'は', 'です'],
      'responseMs': 0
    });
    await tester.pumpAndSettle();
    expect(h.state.reorderIndex, 1);
    expect(h.repository.submitCalls, 0);
    expect(tester.takeException(), isNull);
  });
}
