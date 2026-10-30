import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/core/providers/study_clock_provider.dart';
import 'package:harukoto_mobile/core/providers/user_preferences_provider.dart';
import 'package:harukoto_mobile/features/my/data/my_repository.dart';
import 'package:harukoto_mobile/features/my/providers/my_provider.dart';
import 'package:harukoto_mobile/features/study/data/models/smart_preview_model.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/today_study_sheet.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/today_study_start_button.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';
import 'package:harukoto_mobile/shared/widgets/app_error_retry.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
      'goal confirmation reloads once and disables start until fresh distribution arrives',
      (tester) async {
    final scenario = _Scenario();
    final container = await _pumpSheet(tester, scenario);
    try {
      expect(_start(tester).totalCount, 12);
      await _chooseThirty(tester);
      expect(container.read(userPreferencesProvider).dailyGoal, 30);
      expect(scenario.previewCalls, 1);
      expect(_start(tester).onStart, isNull);

      final refreshed = Completer<SmartPreviewModel>();
      scenario.nextResponse = refreshed.future;
      scenario.saveGate.complete();
      await tester.pump();
      await tester.pump();
      expect(scenario.previewCalls, 2);
      expect(find.byType(TodayStudyStartButton), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      refreshed.complete(_preview(goal: 30, completed: 8));
      await tester.pumpAndSettle();
      expect(_start(tester).totalCount, 22);
      expect(_start(tester).onStart, isNotNull);
      expect(scenario.previewCalls, 2);
      expect(scenario.saveCalls, 1);
      expect(find.text('하루 목표 30개'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    }
  });

  testWidgets(
      'cancel and failed goal save preserve preview and restore the target',
      (tester) async {
    final scenario = _Scenario()..failSave = true;
    final container = await _pumpSheet(tester, scenario);
    try {
      await tester.tap(find.text('하루 목표 20개'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('하루 목표 설정'))).pop();
      await tester.pumpAndSettle();
      expect(scenario.previewCalls, 1);
      expect(scenario.saveCalls, 0);
      expect(_start(tester).totalCount, 12);

      await _chooseThirty(tester);
      expect(_start(tester).onStart, isNull);
      scenario.saveGate.complete();
      await tester.pumpAndSettle();
      expect(container.read(userPreferencesProvider).dailyGoal, 20);
      expect(find.text('하루 목표 20개'), findsOneWidget);
      expect(scenario.previewCalls, 1);
      expect(scenario.saveCalls, 1);
      expect(_start(tester).totalCount, 12);
      expect(_start(tester).onStart, isNotNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    }
  });

  testWidgets(
      'KST rollover hides old distribution during loading and error, then retries fresh',
      (tester) async {
    final scenario = _Scenario();
    final container = await _pumpSheet(tester, scenario);
    try {
      expect(_start(tester).totalCount, 12);
      final nextDay = Completer<SmartPreviewModel>();
      scenario.nextResponse = nextDay.future;
      scenario.now = DateTime.utc(2026, 10, 30, 15);
      container.read(studyDateProvider.notifier).refresh();
      await tester.pump();
      expect(find.byType(TodayStudyStartButton), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      nextDay
          .completeError(StateError('synthetic unavailable new-day preview'));
      await tester.pumpAndSettle();
      expect(find.byType(TodayStudyStartButton), findsNothing);
      expect(find.byType(AppErrorRetry), findsOneWidget);
      scenario.nextResponse = Future.value(_preview(goal: 20, completed: 0));
      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(_start(tester).totalCount, 20);
      expect(_start(tester).onStart, isNotNull);
      expect(scenario.previewCalls, 3);
    } finally {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    }
  });

  testWidgets(
      'an opening account cannot start from an old callback after the reader switches',
      (tester) async {
    final scenario = _Scenario();
    final container = await _pumpSheet(tester, scenario);
    try {
      final start = _start(tester).onStart!;
      scenario.account = 'account-b';
      start();
      await tester.pump();
      expect(find.byType(TodayStudySheet), findsOneWidget);
      expect(scenario.saveCalls, 0);
    } finally {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    }
  });
  testWidgets(
      'a fresh server goal remains usable when local preferences are stale',
      (tester) async {
    final scenario = _Scenario()..goal = 30;
    final container = await _pumpSheet(tester, scenario);
    try {
      expect(container.read(userPreferencesProvider).dailyGoal, 20);
      expect(find.text('하루 목표 30개'), findsOneWidget);
      expect(_start(tester).totalCount, 22);
      expect(_start(tester).onStart, isNotNull);
      await tester.tap(find.text('하루 목표 30개'));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<ListTile>(find.widgetWithText(ListTile, '30개'))
              .selected,
          isTrue);
      await tester.tap(find.text('30개'));
      await tester.pumpAndSettle();
      expect(scenario.saveCalls, 0);
      expect(scenario.previewCalls, 1);
      expect(_start(tester).onStart, isNotNull);
    } finally {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    }
  });
  testWidgets(
      'grammar keeps its existing snapshot and does not watch vocabulary refreshes',
      (tester) async {
    final scenario = _Scenario();
    final container = await _pumpSheet(tester, scenario, category: 'GRAMMAR');
    try {
      expect(_start(tester).totalCount, 10);
      expect(scenario.previewCalls, 0);
      container.read(vocabularyPreviewRefreshProvider.notifier).refresh();
      scenario.now = DateTime.utc(2026, 10, 30, 15);
      container.read(studyDateProvider.notifier).refresh();
      await tester.pumpAndSettle();
      expect(_start(tester).totalCount, 10);
      expect(scenario.previewCalls, 0);
    } finally {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    }
  });

  testWidgets('an account change makes the old live sheet unavailable',
      (tester) async {
    final scenario = _Scenario();
    final container = await _pumpSheet(tester, scenario);
    try {
      scenario.account = 'account-b';
      container.invalidate(currentAccountIdProvider);
      await tester.pumpAndSettle();
      expect(find.byType(TodayStudyStartButton), findsNothing);
      expect(find.byType(AppErrorRetry), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    }
  });
}

TodayStudyStartButton _start(WidgetTester tester) =>
    tester.widget<TodayStudyStartButton>(find.byType(TodayStudyStartButton));

Future<void> _chooseThirty(WidgetTester tester) async {
  await tester.tap(find.text('하루 목표 20개'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('30개'));
  await tester.pump();
  await tester.pump();
}

Future<ProviderContainer> _pumpSheet(WidgetTester tester, _Scenario scenario,
    {String category = 'VOCABULARY'}) async {
  tester.view.physicalSize = const Size(390, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({'user_daily_goal': 20});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    currentAccountIdProvider.overrideWith((ref) => scenario.account),
    currentAccountReaderProvider.overrideWithValue(() => scenario.account),
    studyClockProvider.overrideWithValue(() => scenario.now),
    sharedPreferencesProvider.overrideWithValue(prefs),
    studyRepositoryProvider.overrideWithValue(_StudyRepository(scenario)),
    myRepositoryProvider.overrideWithValue(_MyRepository(scenario)),
  ]);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
        home: Scaffold(
            body: TodayStudySheet(
      data: _preview(goal: 10, completed: 0),
      jlptLevel: 'N5',
      category: category,
    ))),
  ));
  await tester.pumpAndSettle();
  return container;
}

class _Scenario {
  String account = 'account-a';
  DateTime now = DateTime.utc(2026, 10, 30, 14);
  int goal = 20;
  int previewCalls = 0;
  int saveCalls = 0;
  bool failSave = false;
  final saveGate = Completer<void>();
  Future<SmartPreviewModel>? nextResponse;
}

class _StudyRepository extends Fake implements StudyRepository {
  _StudyRepository(this.scenario);
  final _Scenario scenario;
  @override
  Future<SmartPreviewModel> fetchSmartPreview(
      {String category = 'VOCABULARY', String jlptLevel = 'N5'}) {
    scenario.previewCalls++;
    return scenario.nextResponse ?? Future.value(_preview(goal: scenario.goal));
  }
}

class _MyRepository extends MyRepository {
  _MyRepository(this.scenario) : super(Dio());
  final _Scenario scenario;
  @override
  Future<void> updateProfile(Map<String, dynamic> data) async {
    scenario.saveCalls++;
    await scenario.saveGate.future;
    if (scenario.failSave) throw StateError('synthetic failed goal save');
    scenario.goal = data['dailyGoal'] as int;
  }
}

SmartPreviewModel _preview({int goal = 20, int completed = 8}) =>
    SmartPreviewModel.fromJson({
      'poolSize': {'newReady': 100, 'reviewDue': 0, 'retryDue': 0},
      'sessionDistribution': {
        'new': goal - completed,
        'review': 0,
        'retry': 0,
        'total': goal - completed
      },
      'dailyGoal': goal,
      'todayCompleted': completed,
      'overallProgress': {
        'total': 100,
        'studied': 0,
        'mastered': 0,
        'percentage': 0
      },
    });
