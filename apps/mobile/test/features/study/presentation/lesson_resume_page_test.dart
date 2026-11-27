import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_sentence_reorder_step.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/domain/lesson_checkpoint.dart';
import 'package:harukoto_mobile/features/study/domain/lesson_submission.dart';
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
    'real page restores a recognition draft and requires confirmation before advancing',
    (tester) async {
      final before = ResumeHarness();
      await before.recognition();
      before.controller.answerRecognition(before.repository.detail, {
        'order': 2,
        'selectedAnswer': 'b',
        'responseMs': 0,
      });
      before.controller.selectRecognition('c');
      final optionOrder = before.state.layout.recognitionOptions[7];
      await before.controller.flush();
      before.dispose();
      final h = ResumeHarness(store: before.store);
      addTearDown(h.dispose);
      await _mount(tester, h);
      final restored = tester.widget<LessonRecognitionCheckStep>(
        find.byType(LessonRecognitionCheckStep),
      );
      expect(restored.currentIndex, 1);
      expect(restored.selectedOptionId, 'c');
      expect(restored.optionOrder, optionOrder);
      expect(restored.confirmed, isFalse);
      expect(h.repository.fetchCalls, 1);
      expect(h.repository.startCalls, 0);
      expect(h.repository.submitCalls, 0);

      await tester.tap(find.text('마지막 보기'));
      await tester.pumpAndSettle();
      expect(h.state.recognitionSelection, 'd');
      expect(h.state.answers[7], isNull);
      await tester.tap(find.text('답안 확인'));
      await tester.pumpAndSettle();
      expect(h.state.recognitionIndex, 1);
      expect(h.state.answers[7]?['selectedAnswer'], 'd');
      expect(find.text('답안을 확인했어요'), findsOneWidget);
      expect(h.repository.submitCalls, 0);

      await tester.tap(find.text('다음 학습'));
      await tester.pumpAndSettle();
      expect(find.text('단어 매칭'), findsOneWidget);
      expect(h.state.answers[7]?['selectedAnswer'], 'd');
      expect(h.state.recognitionSelection, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a confirmed recognition answer survives Previous and cold resume',
    (tester) async {
      final before = ResumeHarness();
      addTearDown(before.dispose);
      await before.recognition();
      await _mount(tester, before);
      await tester.tap(find.text('둘째 보기'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('답안 확인'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('이전'));
      await tester.pumpAndSettle();
      expect(before.state.step, LessonStep.guidedReading);
      await tester.tap(find.text('다음학습'));
      await tester.pumpAndSettle();
      expect(find.text('다음 문제'), findsOneWidget);
      await before.controller.flush();
      await tester.pumpWidget(const SizedBox.shrink());

      final h = ResumeHarness(store: before.store);
      addTearDown(h.dispose);
      await _mount(tester, h);
      final resumed = tester.widget<LessonRecognitionCheckStep>(
        find.byType(LessonRecognitionCheckStep),
      );
      expect(resumed.confirmed, isTrue);
      expect(resumed.selectedOptionId, 'b');
      expect(resumed.optionOrder, before.state.layout.recognitionOptions[2]);
      expect(find.text('답안을 확인했어요'), findsOneWidget);
      expect(h.repository.startCalls, 0);
      await tester.tap(find.text('다음 문제'));
      await tester.pumpAndSettle();
      expect(h.state.recognitionIndex, 1);
      expect(h.state.answers[2]?['selectedAnswer'], 'b');
      expect(h.state.answers[7], isNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final withRecognition in [true, false]) {
    testWidgets(
        'reorder Previous skips matching with one pair '
        '(recognition: $withRecognition)', (tester) async {
      final h = ResumeHarness(
        repository: ResumeStudyRepository(
          detail: resumeDetail(
            withMatchingPairs: false,
            withRecognition: withRecognition,
          ),
        ),
      );
      addTearDown(h.dispose);
      await h.matching();
      expect(h.state.layout.matchingVocabIds, hasLength(1));
      expect(h.state.restored, isFalse);
      await _mount(tester, h);
      expect(h.state.step, LessonStep.sentenceReorder);

      await tester.tap(find.text('이전'));
      await tester.pumpAndSettle();

      expect(
        h.state.step,
        withRecognition ? LessonStep.recognition : LessonStep.guidedReading,
      );
      expect(h.repository.submitCalls, 0);
    });
  }

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
    expect(find.text('다음 학습'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'real old-account recognition callbacks cannot change a new same-phase account',
      (tester) async {
    final h = ResumeHarness();
    addTearDown(h.dispose);
    await h.recognition();
    await _mount(tester, h);
    final oldWidget = tester.widget<LessonRecognitionCheckStep>(
        find.byType(LessonRecognitionCheckStep));
    h.account = 'account-b';
    h.container.invalidate(currentAccountIdProvider);
    await tester.pump();
    await tester.pumpAndSettle();
    await h.controller.startPractice(h.repository.detail);
    h.controller.selectRecognition('b');
    await tester.pumpAndSettle();
    await h.controller.flush();
    expect(h.state.step, LessonStep.recognition);
    final before = Map<String, String>.from(h.store.values);
    oldWidget.onSelectionChanged('a');
    oldWidget.onConfirm();
    oldWidget.onNext();
    oldWidget.onPrevious?.call();
    await tester.pumpAndSettle();
    expect(h.state.step, LessonStep.recognition);
    expect(h.state.recognitionSelection, 'b');
    expect(h.state.answers, isEmpty);
    expect(h.state.recognitionIndex, 0);
    expect(h.store.values, before);
    expect(h.repository.submitCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'legacy ID-less pending has only record check and never acquires a new submission ID',
      (tester) async {
    final repo =
        ResumeStudyRepository(detail: resumeDetail(progress: completedProgress))
          ..submitError = TimeoutException('lost');
    final before = ResumeHarness(repository: repo);
    await before.recognition();
    final raw = LessonCheckpoint(
            state: before.state.copyWith(submissionPending: true),
            progressStamp: lessonProgressStamp(repo.detail.progress))
        .encode(repo.detail);
    before.store.values[before.store.key(before.account, resumeLessonId)] = raw;
    before.dispose();
    final h = ResumeHarness(store: before.store, repository: repo);
    addTearDown(h.dispose);
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
    expect(repo.submitCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'cold receipt recovery renders historical summary without fetching current content',
      (tester) async {
    final repo = ResumeStudyRepository();
    final before = ResumeHarness(repository: repo);
    await before.recognition();
    repo.submitError = TimeoutException('response lost');
    await before.controller
        .submitAnswers(lessonId: resumeLessonId, jlptLevel: 'N5');
    final envelope = LessonSubmissionEnvelope.inspect(
        before.store.values.values.single, before.account, resumeLessonId)!;
    repo.receipts[envelope.submission.submissionId] =
        LessonSubmissionReceiptModel(
            submissionId: envelope.submission.submissionId,
            processedAt: DateTime.utc(2026, 11, 2),
            result: const LessonSubmitResultModel(
                scoreCorrect: 1,
                scoreTotal: 2,
                results: [],
                status: 'COMPLETED'));
    before.dispose();
    final h = ResumeHarness(repository: repo, store: before.store);
    addTearDown(h.dispose);
    await _mount(tester, h, size: const Size(320, 844), textScale: 2);
    expect(find.text('레슨 제출 결과를 복구했어요'), findsOneWidget);
    expect(find.text('1/2문항 정답'), findsOneWidget);
    expect(find.textContaining('제출 당시'), findsOneWidget);
    expect(repo.fetchCalls, 0);
    expect(find.text('First choice'), findsNothing);
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
    expect(find.text('제출 결과 다시 확인'), findsOneWidget);
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
    await tester.tap(find.byTooltip('레슨 나가기'));
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
    await tester.tap(find.byTooltip('레슨 나가기'));
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

  testWidgets('home tab waits for lesson progress before leaving',
      (tester) async {
    final h = ResumeHarness();
    addTearDown(h.dispose);
    await h.reorder();
    final bank = List<String>.from(h.state.layout.reorderBanks[11]!)
      ..remove('は');
    h.controller.updateReorder(selected: ['は'], available: bank);
    await h.controller.flush();
    final router = await _mountRouted(tester, h);
    h.store.writeGate = Completer<void>();
    await tester.tap(find.bySemanticsLabel('홈 탭'));
    await tester.pump();
    expect(find.byType(LessonPage), findsOneWidget);
    h.store.writeGate!.complete();
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/home');
    expect(find.byType(LessonPage), findsNothing);
    expect(h.store.values.values.single, contains('"reorderSelected":["は"]'));
    expect(tester.takeException(), isNull);
  });
}
