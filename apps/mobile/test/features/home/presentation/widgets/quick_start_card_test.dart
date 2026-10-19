import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';
import 'package:harukoto_mobile/features/home/presentation/widgets/quick_start_card.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_session_model.dart';
import 'package:harukoto_mobile/features/study/data/models/smart_preview_model.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';

void main() {
  testWidgets('continue card shows saved quiz progress instead of mastery',
      (tester) async {
    await _pumpCard(tester, incomplete: _session());
    expect(find.text('이번 퀴즈'), findsOneWidget);
    expect(find.text('1/10문제 저장됨'), findsOneWidget);
    expect(find.text('10%'), findsOneWidget);
    expect(find.text('0%'), findsNothing);
    expect(find.text('이어서 학습하기'), findsOneWidget);

    await tester.tap(find.text('이어서 학습하기'));
    await tester.pumpAndSettle();
    expect(find.text('N5 단어 · 1/10 문제 진행'), findsOneWidget);
  });

  testWidgets('switching category does not relabel another quiz as grammar',
      (tester) async {
    await _pumpCard(tester, incomplete: _session());
    await tester.tap(find.byKey(const ValueKey('quick-start-tab-grammar')));
    await tester.pumpAndSettle();
    expect(find.text('이번 퀴즈'), findsNothing);
    expect(find.text('1/10문제 저장됨'), findsNothing);
    expect(find.text('이어서 학습하기'), findsNothing);
    expect(find.text('오늘의 문법'), findsOneWidget);
    expect(find.text('N5 숙련도'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);
  });

  testWidgets('another level and no quiz show labelled mastery',
      (tester) async {
    await _pumpCard(tester, incomplete: _session(level: 'N4'));
    expect(find.text('이번 퀴즈'), findsNothing);
    expect(find.text('이어서 학습하기'), findsNothing);
    expect(find.text('N5 숙련도'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('loading and unsupported category show no invented zero percent',
      (tester) async {
    final pending = Completer<IncompleteSessionModel?>();
    await _pumpCard(tester, future: pending.future);
    expect(find.text('진행 확인 중'), findsOneWidget);
    expect(find.text('0%'), findsNothing);

    pending.complete(null);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quick-start-tab-sentence')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('quick-start-percentage')), findsNothing);
    expect(find.text('N5 숙련도'), findsNothing);
    expect(find.text('오늘의 문장배열'), findsOneWidget);
  });

  testWidgets('invalid total avoids zero division and keeps resume available',
      (tester) async {
    await _pumpCard(tester, incomplete: _session(total: 0));
    expect(find.text('이번 퀴즈'), findsOneWidget);
    expect(find.text('저장한 답안 확인 필요'), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-start-percentage')), findsNothing);
    expect(find.text('이어서 학습하기'), findsOneWidget);
  });

  testWidgets('saved progress fits a narrow mobile viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpCard(tester, incomplete: _session());
    expect(find.text('1/10문제 저장됨'), findsOneWidget);
    expect(find.text('이번 퀴즈'), findsOneWidget);
  });
}

Future<void> _pumpCard(
  WidgetTester tester, {
  IncompleteSessionModel? incomplete,
  Future<IncompleteSessionModel?>? future,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      incompleteQuizProvider
          .overrideWith((ref) => future ?? Future.value(incomplete)),
      smartPreviewProvider.overrideWith((ref, params) async => _preview()),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: QuickStartCard(
            levelProgress: LevelProgressData(
              vocabulary: ProgressStat(total: 200, mastered: 0, inProgress: 1),
              grammar: ProgressStat(total: 100, mastered: 25, inProgress: 5),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

IncompleteSessionModel _session({String level = 'N5', int total = 10}) =>
    IncompleteSessionModel(
      id: 'saved-session',
      quizType: 'VOCABULARY',
      jlptLevel: level,
      totalQuestions: total,
      answeredCount: 1,
      correctCount: 1,
      startedAt: '2026-10-19T01:00:00Z',
    );

SmartPreviewModel _preview() => SmartPreviewModel.fromJson({
      'poolSize': {'newReady': 10, 'reviewDue': 0, 'retryDue': 0},
      'sessionDistribution': {'new': 10, 'review': 0, 'retry': 0, 'total': 10},
      'dailyGoal': 10,
      'todayCompleted': 0,
      'overallProgress': {
        'total': 100,
        'studied': 0,
        'mastered': 0,
        'percentage': 0
      },
    });
