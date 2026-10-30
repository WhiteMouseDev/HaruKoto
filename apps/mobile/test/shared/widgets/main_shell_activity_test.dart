import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harukoto_mobile/core/network/connectivity_service.dart';
import 'package:harukoto_mobile/core/providers/study_clock_provider.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';
import 'package:harukoto_mobile/features/home/presentation/widgets/streak_daily_card.dart';
import 'package:harukoto_mobile/features/home/providers/study_activity_refresh_provider.dart';
import 'package:harukoto_mobile/features/stats/providers/stats_provider.dart';
import 'package:harukoto_mobile/shared/widgets/bottom_nav.dart';
import 'package:harukoto_mobile/shared/widgets/main_shell.dart';

void main() {
  testWidgets('returning home and app resume refresh activity and Korea date',
      (tester) async {
    var now = DateTime.utc(2026, 9, 27, 14);
    final refresh = _RefreshSpy();
    final container = ProviderContainer(overrides: [
      currentAccountIdProvider.overrideWithValue('test-account'),
      currentAccountReaderProvider.overrideWithValue(() => 'test-account'),
      studyClockProvider.overrideWithValue(() => now),
      studyActivityRefreshProvider.overrideWithValue(refresh),
      connectivityProvider.overrideWith((ref) => Stream.value(true)),
      statsMonthHistoryProvider.overrideWith((ref, period) async => []),
    ]);
    final router = GoRouter(initialLocation: '/home', routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/home',
                builder: (_, __) => Scaffold(
                        body: StreakDailyCard(
                      streak: StreakData.fromJson({}),
                      today: TodayStats.fromJson({}),
                      weeklyStats: const [],
                      dailyGoal: 10,
                    )))
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/study', builder: (_, __) => const Text('Study content'))
          ]),
        ],
      ),
    ]);
    try {
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router)));
      await tester.pumpAndSettle();
      tester.widget<BottomNav>(find.byType(BottomNav)).onTap(1);
      await tester.pumpAndSettle();
      expect(refresh.calls, 0);
      tester.widget<BottomNav>(find.byType(BottomNav)).onTap(0);
      await tester.pumpAndSettle();
      expect(refresh.calls, 1);
      now = DateTime.utc(2026, 9, 27, 15);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(refresh.calls, 2);
      expect(container.read(studyDateProvider), DateTime.utc(2026, 9, 28));
      await tester.tap(find.byKey(const ValueKey('streak-calendar-action')));
      await tester.pumpAndSettle();
      expect(find.text('학습 기록'), findsOneWidget);
      expect(find.byType(BottomNav).hitTestable(), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      container.dispose();
    }
  });
}

class _RefreshSpy extends Fake implements StudyActivityRefresh {
  int calls = 0;
  @override
  void refresh() => calls++;
}
