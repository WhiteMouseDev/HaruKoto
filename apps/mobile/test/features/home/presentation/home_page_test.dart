import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/core/providers/study_clock_provider.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';
import 'package:harukoto_mobile/features/home/data/models/mission_model.dart';
import 'package:harukoto_mobile/features/home/data/models/user_profile_model.dart';
import 'package:harukoto_mobile/features/home/presentation/home_page.dart';
import 'package:harukoto_mobile/features/home/presentation/widgets/streak_daily_card.dart';
import 'package:harukoto_mobile/features/home/providers/home_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('HomePage', () {
    testWidgets('midnight never shows yesterday completion while reloading',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var now = DateTime.utc(2026, 9, 27, 14);
      final nextDashboard = Completer<DashboardModel>();
      var requests = 0;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          currentAccountIdProvider.overrideWithValue('test-account'),
          currentAccountReaderProvider.overrideWithValue(() => 'test-account'),
          sharedPreferencesProvider.overrideWithValue(prefs),
          studyClockProvider.overrideWithValue(() => now),
          dashboardProvider.overrideWith((ref) {
            ref.watch(studyDateProvider);
            requests++;
            return requests == 1
                ? Future.value(DashboardModel.fromJson({
                    'streak': {'current': 2, 'longest': 2, 'studiedToday': true}
                  }))
                : nextDashboard.future;
          }),
          profileProvider.overrideWith((ref) async => const UserProfileModel(
              nickname: 'Test',
              dailyGoal: 10,
              showKana: false,
              jlptLevel: 'N5')),
          missionsProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: HomePage()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('오늘 학습 완료 · 내일도 이어가요'), findsOneWidget);
      final container =
          ProviderScope.containerOf(tester.element(find.byType(HomePage)));
      now = DateTime.utc(2026, 9, 27, 15);
      container.read(studyDateProvider.notifier).refresh();
      await tester.pump();
      expect(find.byType(StreakDailyCard), findsNothing);
      expect(find.text('오늘 학습 완료 · 내일도 이어가요'), findsNothing);
      nextDashboard.complete(DashboardModel.fromJson({
        'streak': {'current': 2, 'longest': 2, 'studiedToday': false}
      }));
      await tester.pumpAndSettle();
      expect(find.text('어제까지의 기록 · 오늘 마치면 3일'), findsOneWidget);
    });

    testWidgets('shows skeleton when all providers are loading',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Use completers that never complete to simulate loading
      final dashboardCompleter = Completer<DashboardModel>();
      final profileCompleter = Completer<UserProfileModel>();
      final missionsCompleter = Completer<List<MissionModel>>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAccountIdProvider.overrideWithValue('test-account'),
            currentAccountReaderProvider
                .overrideWithValue(() => 'test-account'),
            sharedPreferencesProvider.overrideWith((ref) => prefs),
            dashboardProvider.overrideWith(
              (ref) => dashboardCompleter.future,
            ),
            profileProvider.overrideWith(
              (ref) => profileCompleter.future,
            ),
            missionsProvider.overrideWith(
              (ref) => missionsCompleter.future,
            ),
          ],
          child: const MaterialApp(home: HomePage()),
        ),
      );

      // While loading, the Scaffold with AppSkeleton should be shown
      expect(find.byType(Scaffold), findsOneWidget);
      // The error widget should NOT be present
      expect(find.text('데이터를 불러올 수 없습니다'), findsNothing);
      // Neither should data-dependent widgets
      expect(find.text('학습자'), findsNothing);

      // Clean up: complete the futures to avoid pending timers
      dashboardCompleter.completeError('cancelled');
      profileCompleter.completeError('cancelled');
      missionsCompleter.completeError('cancelled');
    });

    testWidgets('shows error state when providers fail with no data',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAccountIdProvider.overrideWithValue('test-account'),
            currentAccountReaderProvider
                .overrideWithValue(() => 'test-account'),
            sharedPreferencesProvider.overrideWith((ref) => prefs),
            dashboardProvider.overrideWith(
              (ref) => Future<DashboardModel>.error(Exception('API down')),
            ),
            profileProvider.overrideWith(
              (ref) => Future<UserProfileModel>.error(Exception('API down')),
            ),
            missionsProvider.overrideWith(
              (ref) => Future<List<MissionModel>>.error(Exception('API down')),
            ),
          ],
          child: const MaterialApp(home: HomePage()),
        ),
      );

      // Let async providers settle
      await tester.pumpAndSettle();

      // AppErrorRetry default message should be visible
      expect(find.text('데이터를 불러올 수 없습니다'), findsOneWidget);
      expect(find.text('다시 시도'), findsOneWidget);
    });

    testWidgets('shows data when providers resolve', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final dashboard = DashboardModel(
        showKana: false,
        today: TodayStats.fromJson({}),
        streak: StreakData.fromJson({}),
        weeklyStats: [],
      );
      const profile = UserProfileModel(
        nickname: 'TestUser',
        dailyGoal: 10,
        showKana: false,
        jlptLevel: 'N5',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentAccountIdProvider.overrideWithValue('test-account'),
            currentAccountReaderProvider
                .overrideWithValue(() => 'test-account'),
            sharedPreferencesProvider.overrideWith((ref) => prefs),
            dashboardProvider.overrideWith(
              (ref) => Future.value(dashboard),
            ),
            profileProvider.overrideWith(
              (ref) => Future.value(profile),
            ),
            missionsProvider.overrideWith(
              (ref) => Future.value(<MissionModel>[]),
            ),
          ],
          child: const MaterialApp(home: HomePage()),
        ),
      );

      // Pump a few frames to let providers resolve (no pumpAndSettle
      // because AppSkeleton has a repeating animation)
      await tester.pump();
      await tester.pump();

      // Should show a time-based greeting with the nickname
      final hour = DateTime.now().hour;
      final String expectedGreeting;
      if (hour >= 5 && hour < 12) {
        expectedGreeting = '오늘도 화이팅, TestUser!';
      } else if (hour >= 12 && hour < 18) {
        expectedGreeting = '점심은 먹었어, TestUser?';
      } else if (hour >= 18) {
        expectedGreeting = '오늘 하루 수고했어, TestUser!';
      } else {
        expectedGreeting = '야행성이구나, TestUser!';
      }
      expect(find.text(expectedGreeting), findsOneWidget);
      // Should NOT show error
      expect(find.text('데이터를 불러올 수 없습니다'), findsNothing);
    });
  });
}
