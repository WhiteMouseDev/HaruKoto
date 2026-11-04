import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/features/kana/domain/kana_card_progress.dart';
import 'package:harukoto_mobile/features/kana/data/kana_card_progress_store.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/network/api_exception.dart';
import 'package:harukoto_mobile/features/kana/data/kana_repository.dart';
import 'package:harukoto_mobile/features/kana/data/models/kana_character_model.dart';
import 'package:harukoto_mobile/features/kana/data/models/kana_stage_model.dart';
import 'package:harukoto_mobile/features/kana/presentation/kana_quiz_page.dart';
import 'package:harukoto_mobile/features/kana/presentation/kana_stage_page.dart';
import 'package:harukoto_mobile/features/kana/presentation/widgets/kana_quiz_content.dart';
import 'package:harukoto_mobile/features/kana/presentation/widgets/kana_quiz_master_result.dart';
import 'package:harukoto_mobile/features/kana/presentation/widgets/stage_complete.dart';
import 'package:harukoto_mobile/features/kana/presentation/widgets/stage_intro.dart';
import 'package:harukoto_mobile/features/kana/presentation/widgets/stage_practice.dart';
import 'package:harukoto_mobile/features/kana/presentation/widgets/stage_quiz.dart';
import 'package:harukoto_mobile/features/kana/presentation/widgets/stage_review.dart';
import 'package:harukoto_mobile/features/kana/providers/kana_provider.dart';
import 'package:harukoto_mobile/features/study/presentation/quiz_result_page.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/result_score_display.dart';

const _failure = ApiException(
    message: 'do not display raw backend failure', statusCode: 503);

void main() {
  for (final stage in [true, false]) {
    final title = stage ? 'stage' : 'standalone';
    testWidgets(
        '$title start failure and empty response never complete; manual retry only',
        (tester) async {
      final repo = _Repository()..startFailures = 1;
      await _pump(tester, repo, stage: stage);
      expect(repo.starts, 1);
      expect(find.text(_failure.userMessage), findsOneWidget);
      expect(find.byType(StageComplete), findsNothing);
      expect(find.byType(QuizResultPage), findsNothing);
      await tester.pump(const Duration(seconds: 15));
      expect(repo.starts, 1);
      repo.emptyStart = true;
      await tester.tap(find.text(stage ? '퀴즈 시작 다시 시도' : '다시 시도'));
      await tester.pumpAndSettle();
      expect(repo.starts, 2);
      expect(find.text('출제할 문제가 없어요. 잠시 후 다시 시도해 주세요.'), findsOneWidget);
      expect(find.byType(StageComplete), findsNothing);
      expect(repo.completions, isEmpty);
      expect(repo.stageSaves, isEmpty);
      repo.emptyStart = false;
      await tester.tap(find.text(stage ? '퀴즈 시작 다시 시도' : '다시 시도'));
      await tester.pumpAndSettle();
      expect(repo.starts, 3);
      expect(find.text('1/2'), findsOneWidget);
    });

    testWidgets(
        '$title answer failure retains question choice/session; retry ACK unlocks progress',
        (tester) async {
      final repo = _Repository()..answerFailures = 1;
      await _pump(tester, repo, stage: stage);
      await tester.tap(find.text('a'));
      await tester.pumpAndSettle();
      expect(find.text('답안을 저장하지 못했어요'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
      expect(_feedback(tester, stage), isFalse);
      expect(_selection(tester, stage), 'a');
      await tester.tap(find.text('b'));
      await tester.pump(const Duration(seconds: 5));
      expect(repo.answers, [('session-1', 'first', 'a')]);
      expect(repo.completions, isEmpty);
      expect(find.text('1/2'), findsOneWidget);
      await tester.ensureVisible(find.text('답안 저장 다시 시도'));
      await tester.tap(find.text('답안 저장 다시 시도'));
      await _flush(tester);
      expect(repo.answers,
          [('session-1', 'first', 'a'), ('session-1', 'first', 'a')]);
      expect(_feedback(tester, stage), isTrue,
          reason: tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data)
              .join(' | '));
      await tester.pump(const Duration(seconds: 1));
      await _flush(tester);
      expect(find.text('2/2'), findsOneWidget);
      expect(repo.starts, 1);
    });

    testWidgets(
        '$title pending answer blocks double tap and waits beyond feedback timer',
        (tester) async {
      final pending = Completer<({bool isCorrect, String correctOptionId})>();
      final repo = _Repository()..answerPending = pending;
      await _pump(tester, repo, stage: stage);
      final question = find.text('first character');
      final firstOption = find.text('a');
      final questionPosition = tester.getRect(question);
      final optionPosition = tester.getRect(firstOption);
      await tester.tap(find.text('a'));
      await tester.tap(find.text('b'));
      await tester.pump(const Duration(seconds: 3));
      expect(repo.answers, hasLength(1));
      expect(find.text('1/2'), findsOneWidget);
      expect(_feedback(tester, stage), isFalse);
      expect(tester.getRect(question), questionPosition);
      expect(tester.getRect(firstOption), optionPosition);
      expect(find.byKey(const ValueKey('kana-answer-status')), findsNothing);
      expect(_pendingIndicator('답안을 저장하고 있어요'), findsOneWidget);
      pending.complete((isCorrect: true, correctOptionId: 'a'));
      await _flush(tester);
      expect(_feedback(tester, stage), isTrue,
          reason: tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data)
              .join(' | '));
      await tester.pump(const Duration(seconds: 1));
      await _flush(tester);
      expect(find.text('2/2'), findsOneWidget);
    });

    testWidgets('$title complete failure stays put and retries same session',
        (tester) async {
      final repo = _Repository()..completeFailures = 1;
      await _pump(tester, repo, stage: stage);
      await _answerAll(tester);
      expect(find.text('결과 저장 다시 시도'), findsOneWidget);
      expect(find.byType(StageComplete), findsNothing);
      expect(find.byType(QuizResultPage), findsNothing);
      expect(repo.completions, ['session-1']);
      expect(repo.stageSaves, isEmpty);
      repo.completionResult = _result(accuracy: 100, xp: 0);
      await tester.ensureVisible(find.text('결과 저장 다시 시도'));
      await tester.tap(find.text('결과 저장 다시 시도'));
      await tester.tap(find.text('결과 저장 다시 시도'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(repo.completions, ['session-1', 'session-1']);
      expect(repo.starts, 1);
      if (stage) {
        expect(find.byType(StageComplete), findsOneWidget);
        expect(find.text('저장된 결과를 확인했어요'), findsOneWidget);
        expect(repo.stageSaves, [('stage-1', 100)]);
      } else {
        expect(find.byType(QuizResultPage), findsOneWidget);
        expect(
            tester
                .widget<ResultScoreDisplay>(find.byType(ResultScoreDisplay))
                .rewardConfirmed,
            isFalse);
        expect(find.text('획득 XP'), findsNothing);
        expect(find.text('결과 저장'), findsOneWidget);
        expect(repo.stageSaves, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        await _flush(tester);
      }
    });

    testWidgets(
        '$title old-account answer cannot advance or trigger completion',
        (tester) async {
      final pending = Completer<({bool isCorrect, String correctOptionId})>();
      final repo = _Repository()..answerPending = pending;
      final account = _Account();
      final container =
          await _pump(tester, repo, stage: stage, account: account);
      await tester.tap(find.text('a'));
      account.id = 'B';
      container.updateOverrides([
        sharedPreferencesProvider
            .overrideWithValue(container.read(sharedPreferencesProvider)),
        currentAccountIdProvider.overrideWithValue('B'),
        currentAccountReaderProvider.overrideWithValue(() => account.id),
        kanaRepositoryProvider.overrideWithValue(repo),
      ]);
      pending.complete((isCorrect: true, correctOptionId: 'a'));
      await tester.pump(const Duration(seconds: 3));
      await _flush(tester);
      expect(find.text('학습 계정이 변경되었어요. 학습 화면에서 다시 시작해 주세요.'), findsOneWidget);
      expect(find.text('2/2'), findsNothing);
      expect(repo.completions, isEmpty);
      expect(repo.stageSaves, isEmpty);
    });

    testWidgets('$title disposed page ignores late start responses',
        (tester) async {
      final start = Completer<StartQuizResponse>();
      final repo = _Repository()..startPending = start;
      await _pump(tester, repo, stage: stage);
      await tester.pumpWidget(const SizedBox.shrink());
      start.complete(_started());
      await _flush(tester);
      expect(tester.takeException(), isNull);
      expect(repo.answers, isEmpty);
    });
  }

  for (final stage in [true, false]) {
    testWidgets(
        '${stage ? 'stage' : 'standalone'} ignores late answer after disposal',
        (tester) async {
      final pending = Completer<({bool isCorrect, String correctOptionId})>();
      final repo = _Repository()..answerPending = pending;
      await _pump(tester, repo, stage: stage);
      await tester.tap(find.text('a'));
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete((isCorrect: true, correctOptionId: 'a'));
      await _flush(tester);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
      expect(repo.completions, isEmpty);
      expect(repo.stageSaves, isEmpty);
    });

    testWidgets(
        '${stage ? 'stage' : 'standalone'} rejects malformed answer ACK without advancing',
        (tester) async {
      final repo = _Repository()..answerOption = 'not-an-option';
      await _pump(tester, repo, stage: stage);
      await tester.tap(find.text('a'));
      await tester.pumpAndSettle();
      expect(_feedback(tester, stage), isFalse);
      expect(_selection(tester, stage), 'a');
      expect(find.text('답안을 저장하지 못했어요'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('1/2'), findsOneWidget);
      expect(repo.completions, isEmpty);
      repo.answerOption = 'a';
      await tester.ensureVisible(find.text('답안 저장 다시 시도'));
      await tester.tap(find.text('답안 저장 다시 시도'));
      await _flush(tester);
      expect(_feedback(tester, stage), isTrue);
      expect(repo.answers,
          [('session-1', 'first', 'a'), ('session-1', 'first', 'a')]);
    });
  }

  testWidgets(
      'stage wrong-answer ACK enters review only after both completion ACKs',
      (tester) async {
    final repo = _Repository()
      ..answerCorrect = false
      ..completionResult = _result(accuracy: 0, xp: 10)
      ..startResult =
          const StartQuizResponse(sessionId: 'session-1', questions: [
        QuizQuestion(
            questionId: '33333333-3333-4333-8333-333333333333',
            questionText: 'first character',
            options: [
              QuizOption(id: 'a', text: 'a'),
              QuizOption(id: 'b', text: 'b')
            ]),
      ]);
    await _pump(tester, repo, stage: true);
    await tester.tap(find.text('b'));
    await _flush(tester);
    expect(_feedback(tester, true), isTrue);
    expect(find.byType(StageReview), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await _flush(tester);
    expect(repo.completions, ['session-1']);
    expect(repo.stageSaves, [('stage-1', 0)]);
    expect(find.byType(StageReview), findsOneWidget);
    expect(find.byType(StageComplete), findsNothing);
    tester.widget<StageReview>(find.byType(StageReview)).onAdvance();
    await _flush(tester);
    expect(find.byType(StageComplete), findsOneWidget);
    expect(find.text('퀴즈 결과: 0/1 정답'), findsOneWidget);
  });

  testWidgets('normal result preserves its existing zero XP presentation',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: ResultScoreDisplay(
      accuracy: 0,
      correct: 0,
      total: 1,
      xpEarned: 0,
      currentXp: 0,
      xpForNext: 100,
    ))));
    await tester.pumpAndSettle();
    expect(find.text('+0'), findsOneWidget);
    expect(find.text('획득 XP'), findsOneWidget);
    expect(find.text('결과 저장'), findsNothing);
  });

  testWidgets(
      'intro progress failure preserves card and same activity on retry',
      (tester) async {
    final repo = _Repository()..cardFailures = 1;
    await _pump(tester, repo, stage: true, enterQuiz: false);
    tester.widget<StageIntro>(find.byType(StageIntro)).onNext();
    await tester.pumpAndSettle();
    expect(find.text('문자 학습 저장을 확인해 주세요'), findsOneWidget);
    expect(tester.widget<StageIntro>(find.byType(StageIntro)).locked, isTrue);
    expect(find.text('1/1'), findsOneWidget);
    expect(find.byType(StagePractice), findsNothing);
    expect(repo.starts, 0);
    final id = repo.cardRequests.single.activityId;
    await tester.tap(find.text('문자 저장 다시 확인'));
    await tester.tap(find.text('문자 저장 다시 확인'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(repo.cardRequests.map((request) => request.activityId), [id, id]);
    expect(repo.cardEffects, 1);
    expect(repo.legacyWrites, 0);
    expect(find.byType(StagePractice), findsOneWidget);
  });

  testWidgets(
      'pending intro disables duplicate Next and waits for acknowledged progress',
      (tester) async {
    final repo = _Repository()..cardGate = Completer<void>();
    await _pump(tester, repo, stage: true, enterQuiz: false);
    final glyph = find.text('あ');
    final glyphPosition = tester.getRect(glyph);
    final next = tester.widget<StageIntro>(find.byType(StageIntro)).onNext;
    next();
    next();
    await _flush(tester);
    expect(repo.cardRequests, hasLength(1));
    expect(find.byType(StagePractice), findsNothing);
    expect(tester.widget<StageIntro>(find.byType(StageIntro)).locked, isTrue);
    expect(tester.getRect(glyph), glyphPosition);
    expect(find.byKey(const ValueKey('kana-card-save-status')), findsNothing);
    expect(_pendingIndicator('문자 학습을 저장하고 있어요'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, '연습하기'))
            .onPressed,
        isNull);
    repo.cardGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(StagePractice), findsOneWidget);
    expect(repo.cardEffects, 1);
    next(); // A callback retained from the old intro card cannot answer practice.
    await tester.pumpAndSettle();
    expect(repo.cardRequests, hasLength(1));
    expect(repo.starts, 0);
  });

  testWidgets(
      'practice Know has distinct action; failed/pending Know cannot be skipped',
      (tester) async {
    final repo = _Repository();
    await _pump(tester, repo, stage: true, enterQuiz: false);
    tester.widget<StageIntro>(find.byType(StageIntro)).onNext();
    await tester.pumpAndSettle();
    await tester.tap(find.text('あ'));
    await tester.pumpAndSettle();
    expect(find.text('아'), findsOneWidget);
    repo.cardGate = Completer<void>();
    final practice = tester.widget<StagePractice>(find.byType(StagePractice));
    practice.onKnow();
    practice.onKnow();
    practice.onDontKnow();
    await _flush(tester);
    expect(tester.widget<StagePractice>(find.byType(StagePractice)).locked,
        isTrue);
    expect(find.text('아'), findsOneWidget);
    expect(find.text('あ'), findsNothing);
    expect(repo.cardRequests, hasLength(2));
    expect(repo.cardRequests.map((request) => request.activityId).toSet(),
        hasLength(2));
    expect(repo.starts, 0);
    repo.cardGate!.complete();
    await tester.pumpAndSettle();
    expect(repo.cardEffects, 2);
    expect(repo.starts, 1);
    expect(repo.legacyWrites, 0);
  });

  testWidgets(
      'cold route/controller restores prepared action without automatic POST',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'auth-fixture': 'keep', 'goal-fixture': 20});
    final prefs = await SharedPreferences.getInstance();
    final repo = _Repository()..cardLoseResponse = true;
    final first = await _pump(tester, repo,
        stage: true, enterQuiz: false, preferences: prefs);
    tester.widget<StageIntro>(find.byType(StageIntro)).onNext();
    await tester.pumpAndSettle();
    final id = repo.cardRequests.single.activityId;
    await tester.pumpWidget(const SizedBox.shrink());
    await _flush(tester);
    // A new container creates new controller/repository consumers; only native
    // preferences and the synthetic server ledger survive this boundary.
    final fresh = await _pump(tester, repo,
        stage: true, enterQuiz: false, preferences: prefs);
    expect(identical(first, fresh), isFalse);
    expect(tester.widget<StageIntro>(find.byType(StageIntro)).locked, isTrue);
    expect(find.text('1/1'), findsOneWidget);
    expect(repo.cardRequests, hasLength(1));
    await tester.tap(find.text('문자 저장 다시 확인'));
    await tester.pumpAndSettle();
    expect(repo.cardRequests.map((request) => request.activityId), [id, id]);
    expect(repo.cardEffects, 1);
    expect(find.byType(StagePractice), findsOneWidget);
    expect(prefs.getString('auth-fixture'), 'keep');
    expect(prefs.getInt('goal-fixture'), 20);
  });

  testWidgets(
      'local preparation and ACK failures retry storage without duplicate POST',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = _FaultCardStore(PreferencesKanaCardProgressStore(prefs))
      ..failWrite = 1;
    final repo = _Repository();
    await _pump(tester, repo,
        stage: true, enterQuiz: false, preferences: prefs, cardStore: store);
    tester.widget<StageIntro>(find.byType(StageIntro)).onNext();
    await tester.pumpAndSettle();
    expect(repo.cardRequests, isEmpty);
    expect(find.text('문자 저장 다시 확인'), findsOneWidget);
    store.failWrite = 3; // retry prepare succeeds, ACK write fails
    await tester.tap(find.text('문자 저장 다시 확인'));
    await tester.pumpAndSettle();
    expect(repo.cardRequests, hasLength(1));
    expect(tester.widget<StageIntro>(find.byType(StageIntro)).locked, isTrue);
    expect(find.text('1/1'), findsOneWidget);
    await tester.tap(find.text('문자 저장 다시 확인'));
    await tester.pumpAndSettle();
    expect(repo.cardRequests, hasLength(1));
    expect(repo.cardEffects, 1);
    expect(find.byType(StagePractice), findsOneWidget);
  });

  testWidgets(
      'quiz-ready recovery requires explicit quiz start and never completes on restore',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _Repository();
    await _pump(tester, repo, stage: true, preferences: prefs);
    expect(repo.starts, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await _flush(tester);
    await _pump(tester, repo,
        stage: true, enterQuiz: false, preferences: prefs);
    expect(find.text('퀴즈 시작'), findsOneWidget);
    expect(repo.starts, 1);
    expect(repo.completions, isEmpty);
    expect(repo.stageSaves, isEmpty);
    await tester.tap(find.text('퀴즈 시작'));
    await tester.pumpAndSettle();
    expect(repo.starts, 2);
    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets(
      'old server 404 keeps new pending request and has no legacy fallback',
      (tester) async {
    final repo = _Repository()
      ..cardFailures = 1
      ..cardFailure =
          const ApiException(message: 'not deployed', statusCode: 404);
    await _pump(tester, repo, stage: true, enterQuiz: false);
    tester.widget<StageIntro>(find.byType(StageIntro)).onNext();
    await tester.pumpAndSettle();
    expect(find.text('요청한 데이터를 찾을 수 없습니다.'), findsOneWidget);
    expect(repo.legacyWrites, 0);
    expect(repo.starts, 0);
    expect(find.text('문자 저장 다시 확인'), findsOneWidget);
  });

  testWidgets('card retry status is readable at 320px and 200% text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = _Repository()..cardFailures = 1;
    await _pump(tester, repo, stage: true, enterQuiz: false, scale: 2);
    tester.widget<StageIntro>(find.byType(StageIntro)).onNext();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('문자 저장 다시 확인'));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('문자 저장 다시 확인'));
    await _flush(tester);
    expect(repo.cardRequests, hasLength(2));
  });

  testWidgets('stage failure retries stage only and uses server accuracy',
      (tester) async {
    final stagePending = Completer<void>();
    final repo = _Repository()
      ..stageFailures = 1
      ..completionResult = _result(accuracy: 80);
    await _pump(tester, repo, stage: true);
    await _answerAll(tester);
    expect(repo.completions, ['session-1']);
    expect(repo.stageSaves, [('stage-1', 80)]);
    expect(find.text('단계 저장 다시 시도'), findsOneWidget);
    expect(find.byType(StageComplete), findsNothing);
    repo.stagePending = stagePending;
    await tester.ensureVisible(find.text('단계 저장 다시 시도'));
    await tester.tap(find.text('단계 저장 다시 시도'));
    await tester.tap(find.text('단계 저장 다시 시도'), warnIfMissed: false);
    await tester.pump(const Duration(seconds: 3));
    expect(repo.stageSaves, [('stage-1', 80), ('stage-1', 80)]);
    expect(repo.completions, ['session-1']);
    expect(find.byType(StageComplete), findsNothing);
    stagePending.complete();
    await tester.pumpAndSettle();
    expect(find.byType(StageComplete), findsOneWidget);
    expect(find.text('+20 XP'), findsOneWidget);
  });

  testWidgets(
      'account switch during quiz completion cannot send stage completion',
      (tester) async {
    final pending = Completer<CompleteQuizResponse>();
    final repo = _Repository()..completePending = pending;
    final account = _Account();
    final container = await _pump(tester, repo, stage: true, account: account);
    await _answerAll(tester, settle: false);
    account.id = 'B';
    container.updateOverrides([
      sharedPreferencesProvider
          .overrideWithValue(container.read(sharedPreferencesProvider)),
      currentAccountIdProvider.overrideWithValue('B'),
      currentAccountReaderProvider.overrideWithValue(() => account.id),
      kanaRepositoryProvider.overrideWithValue(repo),
    ]);
    pending.complete(_result());
    await _flush(tester);
    expect(repo.stageSaves, isEmpty);
    expect(find.byType(StageComplete), findsNothing);
  });

  testWidgets(
      'master pass and accuracy come from server; recovered XP is neutral',
      (tester) async {
    final repo = _Repository()
      ..completeFailures = 1
      ..completionResult = _result(accuracy: 80, xp: 0);
    await _pump(tester, repo, stage: false, master: true);
    await _answerAll(tester);
    await tester.ensureVisible(find.text('결과 저장 다시 시도'));
    await tester.tap(find.text('결과 저장 다시 시도'));
    await tester.pumpAndSettle();
    final view = tester.widget<KanaQuizMasterResultView>(
        find.byType(KanaQuizMasterResultView));
    expect(view.result.correct, 2);
    expect(view.result.accuracy, 80);
    expect(view.result.passed, isFalse);
    expect(view.result.rewardConfirmed, isFalse);
    expect(find.textContaining('+0 XP'), findsNothing);
  });

  for (final stage in [true, false]) {
    testWidgets(
        '${stage ? 'stage' : 'standalone'} answer retry is readable at 320px and 200%',
        (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = _Repository()..answerFailures = 1;
      await _pump(tester, repo, stage: stage, scale: 2);
      await tester.tap(find.text('a'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('답안 저장 다시 시도'));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('답안 저장 다시 시도'));
      await _flush(tester);
      expect(repo.answers, hasLength(2));
    });
  }
}

Finder _pendingIndicator(String label) => find.byWidgetPredicate(
      (widget) =>
          widget is CircularProgressIndicator && widget.semanticsLabel == label,
    );

class _Account {
  String? id = '11111111-1111-4111-8111-111111111111';
}

Future<ProviderContainer> _pump(
  WidgetTester tester,
  _Repository repo, {
  required bool stage,
  bool master = false,
  _Account? account,
  double scale = 1,
  bool enterQuiz = true,
  SharedPreferences? preferences,
  KanaCardProgressStore? cardStore,
}) async {
  final owner = account ?? _Account();
  if (preferences == null) SharedPreferences.setMockInitialValues({});
  final prefs = preferences ?? await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    if (cardStore != null)
      kanaCardProgressStoreProvider.overrideWithValue(cardStore),
    currentAccountIdProvider.overrideWithValue(owner.id),
    currentAccountReaderProvider.overrideWithValue(() => owner.id),
    kanaRepositoryProvider.overrideWithValue(repo),
  ]);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await _flush(tester);
    container.dispose();
  });
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
        builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
        home: stage
            ? const KanaStagePage(type: 'hiragana', stageNumber: 1)
            : KanaQuizPage(type: 'hiragana', isMaster: master)),
  ));
  await _flush(tester);
  if (stage && enterQuiz) {
    await tester.pumpAndSettle();
    tester.widget<StageIntro>(find.byType(StageIntro)).onNext();
    await tester.pumpAndSettle();
    tester.widget<StagePractice>(find.byType(StagePractice)).onDontKnow();
    await _flush(tester);
  }
  if (repo.startPending == null) await tester.pumpAndSettle();
  return container;
}

bool _feedback(WidgetTester tester, bool stage) => stage
    ? tester.widget<StageQuiz>(find.byType(StageQuiz)).showFeedback
    : tester.widget<KanaQuizContent>(find.byType(KanaQuizContent)).showFeedback;
String? _selection(WidgetTester tester, bool stage) => stage
    ? tester.widget<StageQuiz>(find.byType(StageQuiz)).selectedOption
    : tester
        .widget<KanaQuizContent>(find.byType(KanaQuizContent))
        .selectedOption;

Future<void> _answerAll(WidgetTester tester, {bool settle = true}) async {
  for (var i = 0; i < 2; i++) {
    await tester.tap(find.text('a'));
    await _flush(tester);
    await tester.pump(const Duration(seconds: 1));
    await _flush(tester);
  }
  if (settle) await tester.pumpAndSettle();
}

StartQuizResponse _started() =>
    const StartQuizResponse(sessionId: 'session-1', questions: [
      QuizQuestion(
          questionId: 'first',
          questionText: 'first character',
          options: [
            QuizOption(id: 'a', text: 'a'),
            QuizOption(id: 'b', text: 'b')
          ]),
      QuizQuestion(
          questionId: 'second',
          questionText: 'second character',
          options: [
            QuizOption(id: 'a', text: 'a'),
            QuizOption(id: 'b', text: 'b')
          ]),
    ]);
CompleteQuizResponse _result({int accuracy = 100, int xp = 20}) =>
    CompleteQuizResponse(
      accuracy: accuracy,
      xpEarned: xp,
      currentXp: 20,
      xpForNext: 100,
      level: 1,
      events: [],
    );

class _Repository extends Fake implements KanaRepository {
  int starts = 0;
  int startFailures = 0;
  int answerFailures = 0;
  int completeFailures = 0;
  int stageFailures = 0;
  bool emptyStart = false;
  int cardFailures = 0;
  Object cardFailure = _failure;
  bool cardLoseResponse = false;
  Completer<void>? cardGate;
  int cardEffects = 0;
  int legacyWrites = 0;
  final cardRequests = <KanaCardActivity>[];
  final cardReceipts = <String, KanaCardReceipt>{};
  bool answerCorrect = true;
  String answerOption = 'a';
  StartQuizResponse startResult = _started();
  Completer<StartQuizResponse>? startPending;
  Completer<({bool isCorrect, String correctOptionId})>? answerPending;
  Completer<CompleteQuizResponse>? completePending;
  Completer<void>? stagePending;
  CompleteQuizResponse completionResult = _result();
  final answers = <(String, String, String)>[];
  final completions = <String>[];
  final stageSaves = <(String, int?)>[];

  @override
  Future<StartQuizResponse> startQuiz(
      {required String kanaType,
      int? stageNumber,
      required String quizMode,
      required int count}) async {
    starts++;
    if (startFailures-- > 0) throw _failure;
    if (emptyStart) return const StartQuizResponse(questions: []);
    return startPending == null ? startResult : startPending!.future;
  }

  @override
  Future<({bool isCorrect, String correctOptionId})> answerQuestion(
      {required String sessionId,
      required String questionId,
      required String selectedOptionId}) async {
    answers.add((sessionId, questionId, selectedOptionId));
    if (answerFailures-- > 0) throw _failure;
    return answerPending == null
        ? (isCorrect: answerCorrect, correctOptionId: answerOption)
        : answerPending!.future;
  }

  @override
  Future<CompleteQuizResponse> completeQuiz({required String sessionId}) async {
    completions.add(sessionId);
    if (completeFailures-- > 0) throw _failure;
    return completePending == null ? completionResult : completePending!.future;
  }

  @override
  Future<void> completeStage({required String stageId, int? quizScore}) async {
    stageSaves.add((stageId, quizScore));
    if (stageFailures-- > 0) throw _failure;
    await stagePending?.future;
  }

  @override
  Future<KanaCardReceipt> submitCardProgress(KanaCardActivity request,
      {CancelToken? cancelToken}) async {
    cardRequests.add(request);
    await cardGate?.future;
    if (cardFailures-- > 0) throw cardFailure;
    final receipt = cardReceipts.putIfAbsent(request.activityId, () {
      cardEffects++;
      return KanaCardReceipt(
          activityId: request.activityId,
          processedAt: DateTime.utc(2026, 11, 4));
    });
    if (cardLoseResponse) {
      cardLoseResponse = false;
      throw const ApiException(
          message: 'lost response', errorCode: 'NETWORK_TIMEOUT');
    }
    return receipt;
  }

  @override
  Future<void> updateProgress(
      {required String kanaId, required bool learned}) async {
    legacyWrites++;
  }

  @override
  Future<List<KanaStageModel>> fetchStages(String type) async => const [
        KanaStageModel(
            id: 'stage-1',
            kanaType: 'HIRAGANA',
            stageNumber: 1,
            title: '첫 단계',
            description: '첫 문자',
            characters: ['あ'],
            isUnlocked: true,
            isCompleted: false),
      ];
  @override
  Future<List<KanaCharacterModel>> fetchCharacters(String type,
          {String? category}) async =>
      const [
        KanaCharacterModel(
            id: '33333333-3333-4333-8333-333333333333',
            kanaType: 'HIRAGANA',
            character: 'あ',
            romaji: 'a',
            pronunciation: '아',
            row: 'a',
            column: 'a',
            strokeCount: 3,
            category: 'basic',
            order: 1),
      ];
}

Future<void> _flush(WidgetTester tester) async {
  for (var frame = 0; frame < 5; frame++) {
    await tester.pump(const Duration(milliseconds: 1));
  }
}

class _FaultCardStore implements KanaCardProgressStore {
  _FaultCardStore(this.delegate);
  final KanaCardProgressStore delegate;
  int writes = 0;
  int failWrite = -1;
  @override
  Future<String?> read(KanaCardContent content) => delegate.read(content);
  @override
  Future<void> compareAndSet(KanaCardContent content,
      {required String? expected, required String value}) async {
    if (++writes == failWrite) throw const KanaCardStorageException();
    await delegate.compareAndSet(content, expected: expected, value: value);
  }
}
