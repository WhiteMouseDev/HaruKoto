import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/providers/study_clock_provider.dart';
import 'package:harukoto_mobile/features/home/data/models/category_goals_model.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';
import 'package:harukoto_mobile/features/home/presentation/widgets/quick_start_card.dart';
import 'package:harukoto_mobile/features/home/providers/home_provider.dart';
import 'package:harukoto_mobile/features/my/providers/settings_sync_provider.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_session_model.dart';
import 'package:harukoto_mobile/features/study/data/models/smart_preview_model.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';

void main() {
  for (final count in [0, 8, 20, 24]) {
    testWidgets('vocabulary always shows today $count/20 goal progress',
        (tester) async {
      await _pumpCard(tester, count: count);
      expect(find.text('오늘 목표'), findsOneWidget);
      expect(find.text('오늘 $count/20개'), findsOneWidget);
      expect(find.text('${(count / 20 * 100).clamp(0, 100).round()}%'),
          findsOneWidget);
      expect(find.text('N5 숙련도'), findsNothing);
      expect(
        find.text(count >= 20 ? '오늘 목표를 달성했어요' : '목표까지 ${20 - count}개 남았어요'),
        findsOneWidget,
      );
    });
  }

  testWidgets('saved quiz is separate from the daily ring and keeps resume',
      (tester) async {
    await _pumpCard(tester, incomplete: _session());
    expect(find.text('이번 퀴즈 1/10문제 저장됨'), findsOneWidget);
    expect(find.text('오늘 8/20개'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('10%'), findsNothing);
    expect(find.byKey(const ValueKey('quick-start-edit-goal')), findsOneWidget);
    expect(find.text('이어서 학습하기'), findsOneWidget);

    await tester.tap(find.text('이어서 학습하기'));
    await tester.pumpAndSettle();
    expect(find.text('N5 단어 · 1/10 문제 진행'), findsOneWidget);
  });

  testWidgets('switching categories shows only the selected daily progress',
      (tester) async {
    await _pumpCard(tester, incomplete: _session(), hasCategoryGoals: true);
    await tester.tap(find.byKey(const ValueKey('quick-start-tab-grammar')));
    await tester.pumpAndSettle();
    expect(find.text('이번 퀴즈 1/10문제 저장됨'), findsNothing);
    expect(find.text('오늘 8/20개'), findsNothing);
    expect(find.text('이어서 학습하기'), findsNothing);
    expect(find.text('오늘의 문법'), findsOneWidget);
    expect(find.text('N5 숙련도'), findsNothing);
    expect(find.text('오늘 3/15개'), findsOneWidget);
    expect(find.text('20%'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('quick-start-tab-sentence')));
    await tester.pumpAndSettle();
    expect(find.text('오늘 7/10개'), findsOneWidget);
    expect(find.text('70%'), findsOneWidget);
    expect(find.text('N5 숙련도'), findsNothing);
    expect(find.text('오늘의 문장배열'), findsOneWidget);
  });

  testWidgets('grammar still shows its own saved quiz progress',
      (tester) async {
    await _pumpCard(tester,
        incomplete: _session(category: 'GRAMMAR'), hasCategoryGoals: true);
    await tester.tap(find.byKey(const ValueKey('quick-start-tab-grammar')));
    await tester.pumpAndSettle();
    expect(find.text('이번 퀴즈 1/10문제 저장됨'), findsOneWidget);
    expect(find.text('오늘 3/15개'), findsOneWidget);
    expect(find.text('20%'), findsOneWidget);
    expect(find.text('10%'), findsNothing);
    expect(find.text('이어서 학습하기'), findsOneWidget);
  });

  for (final hasSavedQuiz in [false, true]) {
    testWidgets('a pending grammar preview waits with saved quiz $hasSavedQuiz',
        (tester) async {
      final pending = Completer<SmartPreviewModel>();
      await _pumpCard(tester,
          incomplete: hasSavedQuiz ? _session(category: 'GRAMMAR') : null,
          hasCategoryGoals: true,
          grammarPreview: pending.future);
      await tester.tap(find.byKey(const ValueKey('quick-start-tab-grammar')));
      await tester.pumpAndSettle();
      if (hasSavedQuiz) {
        await tester.tap(find.text('이어서 학습하기'));
        await tester.pumpAndSettle();
        expect(find.text('진행 중인 학습이 있어요'), findsOneWidget);
        await tester.tap(find.text('오늘의 학습 보기'));
      } else {
        await tester.tap(find.text('오늘의 문법'));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      pending.complete(_preview());
      await tester.pumpAndSettle();
      expect(find.text('오늘의 학습'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  }

  testWidgets('another level cannot change the daily count or offer resume',
      (tester) async {
    await _pumpCard(tester, incomplete: _session(level: 'N4'));
    expect(
        find.byKey(const ValueKey('quick-start-saved-progress')), findsNothing);
    expect(find.text('이어서 학습하기'), findsNothing);
    expect(find.text('오늘 8/20개'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
  });

  testWidgets('saved quiz loading and errors do not block a valid daily goal',
      (tester) async {
    final pending = Completer<IncompleteSessionModel?>();
    await _pumpCard(tester, future: pending.future);
    expect(find.text('오늘 8/20개'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('이어서 학습하기'), findsNothing);

    pending.completeError(StateError('synthetic unavailable saved quiz'));
    await tester.pumpAndSettle();
    expect(find.text('오늘 8/20개'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('이어서 학습하기'), findsNothing);
  });

  testWidgets('unknown or stale daily data and invalid goals never invent zero',
      (tester) async {
    for (final state in [
      (hasGoal: false, date: '2026-10-30', goal: 20),
      (hasGoal: true, date: '2026-10-29', goal: 20),
      (hasGoal: true, date: '2026-10-31', goal: 20),
      (hasGoal: true, date: '2026-10-30', goal: 0),
      (hasGoal: true, date: '2026-10-30', goal: -1),
    ]) {
      await _pumpCard(tester,
          hasGoal: state.hasGoal, date: state.date, dailyGoal: state.goal);
      expect(find.text('오늘 목표'), findsOneWidget);
      expect(find.text('오늘 학습량 확인 필요'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('quick-start-percentage')), findsNothing);
      expect(find.text('0%'), findsNothing);
    }
  });

  testWidgets('invalid quiz total leaves daily ring and resume available',
      (tester) async {
    await _pumpCard(tester, incomplete: _session(total: 0));
    expect(find.text('이번 퀴즈 저장한 답안 확인 필요'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('이어서 학습하기'), findsOneWidget);
  });

  testWidgets('daily goal editor stays available with saved quiz and cancels',
      (tester) async {
    final settings = _SettingsSpy();
    await _pumpCard(tester, incomplete: _session(), settings: settings);
    await tester.tap(find.byKey(const ValueKey('quick-start-edit-goal')));
    await tester.pumpAndSettle();
    expect(find.text('하루 목표 설정'), findsOneWidget);
    expect(settings.goals, isEmpty);
    Navigator.of(tester.element(find.text('하루 목표 설정'))).pop();
    await tester.pumpAndSettle();
    expect(settings.goals, isEmpty);
    expect(find.text('오늘 8/20개'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('quick-start-edit-goal')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30개'));
    await tester.pumpAndSettle();
    expect(settings.goals, [30]);
    expect(find.text('하루 목표 설정'), findsNothing);
  });

  testWidgets('all three edits send only their selected category',
      (tester) async {
    final settings = _SettingsSpy();
    await _pumpCard(tester, hasCategoryGoals: true, settings: settings);
    for (final category in DailyGoalCategory.values) {
      await tester
          .tap(find.byKey(ValueKey('quick-start-tab-${category.name}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quick-start-edit-goal')));
      await tester.pumpAndSettle();
      expect(find.text('${category.label} 하루 목표 설정'), findsOneWidget);
      await tester.tap(find.text('30개'));
      await tester.pumpAndSettle();
    }
    expect(settings.goals, isEmpty);
    expect(settings.categoryGoals, [
      (DailyGoalCategory.vocabulary, 30),
      (DailyGoalCategory.grammar, 30),
      (DailyGoalCategory.sentence, 30),
    ]);
  });

  testWidgets('older dashboards never expose shared edits in other categories',
      (tester) async {
    await _pumpCard(tester);
    for (final category in ['grammar', 'sentence']) {
      await tester.tap(find.byKey(ValueKey('quick-start-tab-$category')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('quick-start-edit-goal')), findsNothing);
      expect(find.text('오늘 학습량 확인 필요'), findsOneWidget);
      expect(find.text('오늘 8/20개'), findsNothing);
    }
  });

  testWidgets('daily and saved progress fit 320px with enlarged text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpCard(tester, incomplete: _session(), textScale: 1.6);
    expect(find.text('이번 퀴즈\n1/10문제 저장됨'), findsOneWidget);
    expect(find.text('오늘 8/20개'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    final editSize =
        tester.getSize(find.byKey(const ValueKey('quick-start-edit-goal')));
    expect(editSize.width, greaterThanOrEqualTo(48));
    expect(editSize.height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpCard(
  WidgetTester tester, {
  IncompleteSessionModel? incomplete,
  Future<IncompleteSessionModel?>? future,
  int count = 8,
  int dailyGoal = 20,
  String date = '2026-10-30',
  bool hasGoal = true,
  bool hasCategoryGoals = false,
  double textScale = 1,
  _SettingsSpy? settings,
  Future<SmartPreviewModel>? grammarPreview,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentAccountIdProvider.overrideWithValue('account-a'),
      currentAccountReaderProvider.overrideWithValue(() => 'account-a'),
      studyClockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 30, 3)),
      incompleteQuizProvider
          .overrideWith((ref) => future ?? Future.value(incomplete)),
      smartPreviewProvider.overrideWith((ref, params) =>
          params.category == 'GRAMMAR' && grammarPreview != null
              ? grammarPreview
              : Future.value(_preview())),
      dashboardProvider
          .overrideWith((ref) async => DashboardModel.fromJson({})),
      if (settings != null)
        settingsSyncServiceProvider.overrideWithValue(settings),
    ],
    child: MaterialApp(
      home: Builder(
          builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(textScale)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: QuickStartCard(
                      dailyGoal: dailyGoal,
                      today: TodayStats.fromJson({
                        'wordsStudied': 99,
                        'xpEarned': 100,
                        if (hasCategoryGoals)
                          'categoryGoals': {
                            'date': date,
                            'vocabulary': {
                              'target': dailyGoal,
                              'answeredCount': count
                            },
                            'grammar': {'target': 15, 'answeredCount': 3},
                            'sentence': {'target': 10, 'answeredCount': 7},
                          },
                        if (hasGoal)
                          'vocabularyGoal': {
                            'date': date,
                            'answeredCount': count
                          },
                      }),
                      levelProgress: const LevelProgressData(
                        vocabulary: ProgressStat(
                            total: 200, mastered: 0, inProgress: 1),
                        grammar: ProgressStat(
                            total: 100, mastered: 25, inProgress: 5),
                      ),
                    ),
                  ),
                ),
              )),
    ),
  ));
  await tester.pump();
  await tester.pump();
}

IncompleteSessionModel _session({
  String category = 'VOCABULARY',
  String level = 'N5',
  int total = 10,
}) =>
    IncompleteSessionModel(
      id: 'saved-session',
      quizType: category,
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

class _SettingsSpy extends Fake implements SettingsSyncService {
  final goals = <int>[];
  final categoryGoals = <(DailyGoalCategory, int)>[];

  @override
  Future<void> updateCategoryDailyGoal(
          DailyGoalCategory category, int value) async =>
      categoryGoals.add((category, value));
  @override
  Future<void> updateDailyGoal(int value) async => goals.add(value);
}
