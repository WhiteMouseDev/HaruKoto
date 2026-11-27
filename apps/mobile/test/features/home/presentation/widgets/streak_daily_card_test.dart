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
import 'package:harukoto_mobile/features/home/providers/home_provider.dart';
import 'package:harukoto_mobile/features/stats/data/models/stats_history_model.dart';
import 'package:harukoto_mobile/features/stats/data/stats_repository.dart';
import 'package:harukoto_mobile/features/stats/providers/stats_provider.dart';

void main() {
  testWidgets('distinguishes today pending from an already completed streak',
      (tester) async {
    await _pumpCard(tester, streak: _streak(current: 3));
    expect(find.text('연속 학습'), findsOneWidget);
    expect(find.text('3일'), findsOneWidget);
    expect(
      find.bySemanticsLabel('3일 연속 학습. 어제까지의 기록 · 오늘 학습하면 4일. 학습 기록 보기'),
      findsOneWidget,
    );
  });

  testWidgets('today completed takes priority even with a zero current count',
      (tester) async {
    await _pumpCard(tester, streak: _streak(studied: true));
    expect(find.text('0일'), findsOneWidget);
    expect(
      find.bySemanticsLabel('오늘도 학습했어요. 오늘의 학습 기록을 남겼어요. 학습 기록 보기'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('9월 27일 일요일, 오늘, 학습 기록 있음'), findsOneWidget);
  });

  testWidgets('week uses date keys, Monday order and explicit completion flags',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
    final weekdaysY = {
      for (final label in _labels) tester.getCenter(find.text(label)).dy,
    };
    expect(weekdaysY, hasLength(1));
    final petals = find.byWidgetPredicate(
      (widget) =>
          widget is Image &&
          widget.image is AssetImage &&
          (widget.image as AssetImage).assetName.startsWith(
                'assets/icons/figma-home-petal-',
              ),
    );
    expect(petals, findsNWidgets(_labels.length));
    for (final (index, label) in _labels.indexed) {
      final offset = tester.getCenter(find.text(label)) -
          tester.getCenter(petals.at(index));
      expect(offset.dx, closeTo(-0.5, 0.001), reason: label);
      expect(offset.dy, closeTo(2, 0.001), reason: label);
    }
    expect(
      tester
          .getSize(find.byKey(const ValueKey('streak-calendar-action')))
          .height,
      lessThanOrEqualTo(70),
    );
    expect(find.bySemanticsLabel('9월 21일 월요일, 학습 기록 있음'), findsOneWidget);
    expect(find.bySemanticsLabel('9월 22일 화요일, 학습 기록 없음'), findsOneWidget);
    expect(find.bySemanticsLabel('9월 24일 목요일, 학습 기록 있음'), findsOneWidget);
    expect(find.byKey(const ValueKey('streak-week-today')), findsOneWidget);
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
      expect(find.byKey(const ValueKey('streak-week-today')), findsOneWidget);
      expect(find.bySemanticsLabel('9월 23일 수요일, 오늘, 학습 기록 있음'), findsOneWidget);
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
    expect(find.text('학습한 날'), findsNothing);

    pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('학습 기록을 불러오지 못했어요'), findsOneWidget);
    expect(find.text('학습한 날'), findsNothing);
    repository.result = Future.value([
      StatsHistoryRecord.fromJson({'date': '2026-09-27', 'hasStudied': true}),
    ]);
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(repository.calls, [(2026, 9), (2026, 9)]);
    expect(find.text('학습 기록을 불러오지 못했어요'), findsNothing);
    expect(find.text('학습한 날'), findsOneWidget);
    expect(find.bySemanticsLabel('2026년 9월 27일 일요일, 오늘, 학습 기록 있음'),
        findsOneWidget);

    await tester.tap(find.byTooltip('이전 달'));
    await tester.pumpAndSettle();
    expect(repository.calls.last, (2026, 8));
    expect(find.text('2026'), findsOneWidget);
    expect(find.text('8월'), findsOneWidget);
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
        StatsHistoryRecord.fromJson({
          'date': '2026-09-25',
          'hasStudied': true,
          'goalAchieved': true,
        }),
        StatsHistoryRecord.fromJson({
          'date': '2026-09-28',
          'hasStudied': true,
          'goalAchieved': true,
        }),
      ]);
    await _pumpCard(tester,
        repository: repository, streak: _streak(current: 5, longest: 9));
    await tester.tap(find.byKey(const ValueKey('streak-calendar-action')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('2026년 9월 21일 월요일, 학습 기록 없음'), findsOneWidget);
    expect(find.bySemanticsLabel('2026년 9월 22일 화요일, 학습 기록 있음'), findsOneWidget);
    expect(find.bySemanticsLabel('2026년 9월 23일 수요일, 학습 기록 없음'), findsOneWidget);
    expect(find.bySemanticsLabel('2026년 9월 24일 목요일, 학습 기록 있음'), findsOneWidget);
    expect(find.bySemanticsLabel('2026년 9월 25일 금요일, 학습 기록 있음, 하루 목표 달성'),
        findsOneWidget);
    expect(find.bySemanticsLabel('2026년 9월 28일 월요일, 예정'), findsOneWidget);
    final sheet = find.byType(BottomSheet);
    final title = find.text('연속 학습 5일');
    expect(title, findsOneWidget);
    expect(find.textContaining('최장'), findsNothing);
    final headers = [
      for (final label in ['일', '월', '화', '수', '목', '금', '토'])
        tester
            .getCenter(find.descendant(of: sheet, matching: find.text(label)))
            .dx,
    ];
    expect(headers, orderedEquals(headers.toList()..sort()));
    final sunday = find.bySemanticsLabel('2026년 9월 27일 일요일, 오늘, 학습 기록 없음');
    expect(tester.getCenter(sunday).dx, closeTo(headers.first, 0.1));
    final goalDay =
        find.bySemanticsLabel('2026년 9월 25일 금요일, 학습 기록 있음, 하루 목표 달성');
    expect(find.descendant(of: goalDay, matching: find.text('25')),
        findsOneWidget);
    expect(
      find.descendant(of: goalDay, matching: find.byType(Image)),
      findsOneWidget,
    );
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
    expect(find.text('연속 학습 0일'), findsNothing);
    final afterSwitch = repository.calls.length;
    retry();
    await tester.pumpAndSettle();
    expect(repository.calls.length, afterSwitch);
    expect(tester.takeException(), isNull);
  });

  testWidgets('open calendar refreshes the current streak at Korea midnight',
      (tester) async {
    var now = DateTime.utc(2026, 9, 27, 14, 59);
    final nextStreak = Completer<StreakData>();
    await _pumpCard(
      tester,
      clock: () => now,
      streak: _streak(current: 5, longest: 9),
      loadStreak: (date) async =>
          date.day == 27 ? _streak(current: 5, longest: 9) : nextStreak.future,
    );
    final container =
        ProviderScope.containerOf(tester.element(find.byType(StreakDailyCard)));
    await tester.tap(find.byKey(const ValueKey('streak-calendar-action')));
    await tester.pumpAndSettle();
    expect(find.text('연속 학습 5일'), findsOneWidget);

    now = DateTime.utc(2026, 9, 27, 15);
    container.read(studyDateProvider.notifier).refresh();
    await tester.pump();
    await tester.pump();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('연속 학습 5일'), findsNothing);
    expect(find.text('연속 학습 —'), findsOneWidget);

    nextStreak.complete(_streak(longest: 9));
    await tester.pumpAndSettle();
    expect(find.text('연속 학습 0일'), findsOneWidget);
    expect(find.bySemanticsLabel('2026년 9월 28일 월요일, 오늘, 학습 기록 없음'),
        findsOneWidget);
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
          expect(find.text('연속 학습'), findsOneWidget);
          expect(find.text('${status.current}일'), findsOneWidget);
          final action = tester.getSemantics(
              find.byKey(const ValueKey('streak-calendar-action')));
          expect(
              action.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
          action.owner!.performAction(action.id, SemanticsAction.tap);
          await tester.pumpAndSettle();
          expect(find.text('연속 학습 ${status.current}일'), findsOneWidget);
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
  DateTime Function()? clock,
  Future<StreakData> Function(DateTime)? loadStreak,
  _HistoryRepository? repository,
  Brightness brightness = Brightness.light,
  double scale = 1,
  String? Function()? account,
}) async {
  final initialStreak = streak ?? _streak();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      currentAccountIdProvider
          .overrideWith((ref) => account == null ? 'test-account' : account()),
      currentAccountReaderProvider
          .overrideWithValue(account ?? () => 'test-account'),
      studyClockProvider.overrideWithValue(
          clock ?? () => now ?? DateTime.utc(2026, 9, 27, 3)),
      dashboardProvider.overrideWith((ref) async {
        final date = ref.watch(studyDateProvider);
        return DashboardModel(
          showKana: false,
          today: TodayStats.fromJson({}),
          streak: loadStreak == null ? initialStreak : await loadStreak(date),
          weeklyStats: weeklyStats,
        );
      }),
      statsRepositoryProvider
          .overrideWithValue(repository ?? _HistoryRepository()),
    ],
    child: MaterialApp(
      theme: ThemeData(brightness: brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: StreakDailyCard(
            streak: initialStreak,
            today: TodayStats.fromJson({}),
            weeklyStats: weeklyStats,
            dailyGoal: 10,
          ),
        ),
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
