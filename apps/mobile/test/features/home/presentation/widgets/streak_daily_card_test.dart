import 'package:harukoto_mobile/core/constants/colors.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'dart:async';
import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/providers/study_clock_provider.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';
import 'package:harukoto_mobile/features/home/presentation/widgets/streak_daily_card.dart';
import 'package:harukoto_mobile/features/stats/data/models/stats_history_model.dart';
import 'package:harukoto_mobile/features/stats/data/stats_repository.dart';
import 'package:harukoto_mobile/features/stats/providers/stats_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

void main() {
  testWidgets('distinguishes today pending from an already completed streak',
      (tester) async {
    await _pumpCard(tester, streak: _streak(current: 3));
    expect(find.text('3일 연속 학습'), findsOneWidget);
    expect(find.text('어제까지의 기록 · 오늘 마치면 4일'), findsOneWidget);
    expect(find.text('오늘 학습 완료'), findsNothing);
  });

  testWidgets('today completed takes priority even with a zero current count',
      (tester) async {
    await _pumpCard(tester, streak: _streak(studied: true));
    expect(find.text('오늘 학습 완료'), findsOneWidget);
    expect(find.text('오늘의 학습 기록을 남겼어요'), findsOneWidget);
    expect(find.text('첫 학습을 시작해요'), findsNothing);
  });

  testWidgets('week uses date keys, Monday order and explicit completion flags',
      (tester) async {
    await _pumpCard(tester, weeklyStats: [
      _entry('2026-09-24', true),
      _entry('2026-09-21', true),
      _entry('2026-09-20', true),
      _entry('2026-09-22', false, xp: 30),
    ]);
    final labels = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .where((text) => _labels.contains(text))
        .toList();
    expect(labels, _labels);
    expect(find.byIcon(LucideIcons.check), findsNWidgets(2));
    expect(find.text('오늘'), findsOneWidget);
  });

  testWidgets(
      'today remains identified when complete and future is not complete',
      (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await _pumpCard(tester,
          now: DateTime.utc(2026, 9, 23, 3),
          streak: _streak(current: 2, studied: true),
          weeklyStats: [_entry('2026-09-27', true)]);
      expect(find.text('오늘'), findsOneWidget);
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
      expect(find.bySemanticsLabel('9월 23일 수요일, 오늘, 학습 완료'), findsOneWidget);
      expect(find.bySemanticsLabel('9월 27일 일요일, 예정'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
      'calendar exposes loading, failure and retry for only its visible month',
      (tester) async {
    final repository = _HistoryRepository();
    final pending = Completer<List<StatsHistoryRecord>>();
    repository.result = pending.future;
    await _pumpCard(tester, repository: repository);
    await tester.tap(find.byKey(const ValueKey('streak-calendar-action')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(repository.calls, [(2026, 9)]);
    expect(find.text('체크는 학습 완료 · 테두리는 오늘'), findsNothing);

    pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('학습 기록을 불러오지 못했어요'), findsOneWidget);
    expect(find.text('체크는 학습 완료 · 테두리는 오늘'), findsNothing);
    repository.result = Future.value([
      StatsHistoryRecord.fromJson({'date': '2026-09-27', 'hasStudied': true}),
    ]);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(repository.calls, [(2026, 9), (2026, 9)]);
    expect(find.text('학습 기록을 불러오지 못했어요'), findsNothing);
    expect(find.text('체크는 학습 완료 · 테두리는 오늘'), findsOneWidget);
    expect(find.byIcon(LucideIcons.check), findsOneWidget);

    await tester.tap(find.byTooltip('이전 달'));
    await tester.pumpAndSettle();
    expect(repository.calls.last, (2026, 8));
    expect(find.text('2026년 8월'), findsOneWidget);
  });

  testWidgets(
      'calendar respects old/new activity flags without inventing marks',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final repository = _HistoryRepository()
      ..result = Future.value([
        StatsHistoryRecord.fromJson({'date': '2026-09-21'}),
        StatsHistoryRecord.fromJson({'date': '2026-09-22', 'xpEarned': 25}),
        StatsHistoryRecord.fromJson(
            {'date': '2026-09-23', 'hasStudied': false, 'xpEarned': 50}),
        StatsHistoryRecord.fromJson({'date': '2026-09-24', 'hasStudied': true}),
        StatsHistoryRecord.fromJson({'date': '2026-09-28', 'hasStudied': true}),
      ]);
    await _pumpCard(tester, repository: repository);
    await tester.tap(find.byKey(const ValueKey('streak-calendar-action')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('2026년 9월 21일 월요일, 학습 기록 없음'), findsOneWidget);
    expect(find.bySemanticsLabel('2026년 9월 22일 화요일, 학습 완료'), findsOneWidget);
    expect(find.bySemanticsLabel('2026년 9월 23일 수요일, 학습 기록 없음'), findsOneWidget);
    expect(find.bySemanticsLabel('2026년 9월 24일 목요일, 학습 완료'), findsOneWidget);
    expect(find.bySemanticsLabel('2026년 9월 28일 월요일, 예정'), findsOneWidget);
    expect(find.textContaining('하루에 한 번만'), findsNothing);
    semantics.dispose();
  });

  testWidgets('calendar hides old account data and rejects a retained retry',
      (tester) async {
    var account = 'account-a';
    final repository = _HistoryRepository()..error = StateError('offline');
    await _pumpCard(tester, repository: repository, account: () => account);
    final container =
        ProviderScope.containerOf(tester.element(find.byType(StreakDailyCard)));
    await tester.tap(find.byKey(const ValueKey('streak-calendar-action')));
    await tester.pumpAndSettle();
    final retry = tester
        .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, '다시 시도'))
        .onPressed!;
    final before = repository.calls.length;
    account = 'account-b';
    retry(); // Authoritative session changed before auth stream delivery.
    await tester.pump();
    expect(repository.calls.length, before);
    container.invalidate(currentAccountIdProvider);
    await tester.pumpAndSettle();
    expect(find.text('계정이 변경됐어요. 학습 기록을 다시 열어주세요.'), findsOneWidget);
    expect(find.text('최장 0일 · 한국 시간 기준'), findsNothing);
    final afterSwitch = repository.calls.length;
    retry();
    await tester.pumpAndSettle();
    expect(repository.calls.length, afterSwitch);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('history error and readable retry fit 320px/2x in $brightness',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _HistoryRepository()..error = StateError('offline');
      await _pumpCard(tester,
          repository: repository, brightness: brightness, scale: 2);
      await tester.tap(find.byKey(const ValueKey('streak-calendar-action')));
      await tester.pumpAndSettle();
      final button = find.widgetWithText(OutlinedButton, '다시 시도');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      expect(
          tester
              .widget<OutlinedButton>(button)
              .style!
              .foregroundColor!
              .resolve({}),
          brightness == Brightness.light
              ? AppColors.sakuraOn
              : AppColors.primaryContainer);
      expect(tester.takeException(), isNull);
    });
  }

  for (final brightness in Brightness.values) {
    for (final status in [
      _streak(),
      _streak(longest: 4),
      _streak(current: 123, longest: 123),
      _streak(current: 123, longest: 123, studied: true),
    ]) {
      testWidgets(
          'card and calendar fit 320px/2x $brightness ${status.current}/${status.longest}/${status.studiedToday}',
          (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final semantics = tester.ensureSemantics();
        try {
          await _pumpCard(tester,
              streak: status, brightness: brightness, scale: 2);
          expect(tester.takeException(), isNull);
          expect(find.text('기록 보기 · 한국 시간 기준'), findsOneWidget);
          final action = tester.getSemantics(
              find.byKey(const ValueKey('streak-calendar-action')));
          expect(
              action.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
          action.owner!.performAction(action.id, SemanticsAction.tap);
          await tester.pumpAndSettle();
          expect(find.text('학습 기록'), findsOneWidget);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      });
    }
  }
}

const _labels = ['월', '화', '수', '목', '금', '토', '일'];
StreakData _streak({int current = 0, int longest = 0, bool studied = false}) =>
    StreakData(
      current: current,
      longest: longest,
      studiedToday: studied,
      needsActionToday: current > 0 && !studied,
    );
WeeklyStatEntry _entry(String date, bool studied, {int xp = 0}) =>
    WeeklyStatEntry(
      date: date,
      wordsStudied: 0,
      xpEarned: xp,
      hasStudied: studied,
    );
Future<void> _pumpCard(
  WidgetTester tester, {
  StreakData? streak,
  List<WeeklyStatEntry> weeklyStats = const [],
  DateTime? now,
  _HistoryRepository? repository,
  Brightness brightness = Brightness.light,
  double scale = 1,
  String? Function()? account,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentAccountIdProvider
          .overrideWith((ref) => account == null ? 'test-account' : account()),
      currentAccountReaderProvider
          .overrideWithValue(account ?? () => 'test-account'),
      studyClockProvider
          .overrideWithValue(() => now ?? DateTime.utc(2026, 9, 27, 3)),
      statsRepositoryProvider
          .overrideWithValue(repository ?? _HistoryRepository()),
    ],
    child: MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: MediaQuery(
        data: MediaQueryData(
            textScaler: TextScaler.linear(scale), disableAnimations: true),
        child: Scaffold(
            body: SingleChildScrollView(
                child: StreakDailyCard(
          streak: streak ?? _streak(),
          today: TodayStats.fromJson({}),
          weeklyStats: weeklyStats,
          dailyGoal: 10,
        ))),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

class _HistoryRepository extends Fake implements StatsRepository {
  final calls = <(int, int)>[];
  Future<List<StatsHistoryRecord>> result = Future.value([]);
  Object? error;
  @override
  Future<List<StatsHistoryRecord>> fetchMonthHistory(int year, int month) {
    calls.add((year, month));
    if (error != null) return Future.error(error!);
    return result;
  }
}
