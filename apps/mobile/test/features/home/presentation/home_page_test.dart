import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/core/providers/study_clock_provider.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';
import 'package:harukoto_mobile/features/home/data/models/mission_model.dart';
import 'package:harukoto_mobile/features/home/data/models/user_profile_model.dart';
import 'package:harukoto_mobile/features/home/presentation/home_page.dart';
import 'package:harukoto_mobile/features/home/presentation/widgets/home_header.dart';
import 'package:harukoto_mobile/features/home/presentation/widgets/streak_daily_card.dart';
import 'package:harukoto_mobile/features/home/providers/home_provider.dart';
import 'package:harukoto_mobile/features/notifications/data/models/notification_model.dart';
import 'package:harukoto_mobile/features/notifications/providers/notification_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('HomePage', () {
    testWidgets('logo-free header opens notifications from its Figma bell',
        (tester) async {
      final router = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: HomeTitleBar()),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const Scaffold(body: Text('알림 목록')),
        ),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          notificationsProvider.overrideWith(
            (ref) async => const NotificationsResponse(
              notifications: [],
              unreadCount: 12,
            ),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();

      final title = find.text('홈');
      final bell = find.byType(IconButton);
      final asset = find.byType(Image);
      expect(title, findsOneWidget);
      expect(tester.getCenter(title).dx, lessThan(tester.getCenter(bell).dx));
      expect(asset, findsOneWidget);
      expect((tester.widget<Image>(asset).image as AssetImage).assetName,
          'assets/icons/figma-home-bell.png');
      expect(find.text('9+'), findsOneWidget);
      expect(tester.getSemantics(bell).getSemanticsData().tooltip,
          '알림, 읽지 않은 알림 12개');

      await tester.tap(bell);
      await tester.pumpAndSettle();
      expect(find.text('알림 목록'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

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
      final studiedToday = find.bySemanticsLabel(RegExp('오늘도 학습했어요'));
      expect(studiedToday, findsOneWidget);
      final container =
          ProviderScope.containerOf(tester.element(find.byType(HomePage)));
      now = DateTime.utc(2026, 9, 27, 15);
      container.read(studyDateProvider.notifier).refresh();
      await tester.pump();
      expect(find.byType(StreakDailyCard), findsNothing);
      expect(studiedToday, findsNothing);
      nextDashboard.complete(DashboardModel.fromJson({
        'streak': {'current': 2, 'longest': 2, 'studiedToday': false}
      }));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(RegExp('어제까지의 기록 · 오늘 학습하면 3일')),
        findsOneWidget,
      );
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

      final title = find.text('홈');
      final streak = find.text('연속 학습');
      final greeting = find.text('TestUser님, 오늘도 힘내볼까요?');
      expect(greeting, findsOneWidget);
      expect(
          tester.getTopLeft(title).dy, lessThan(tester.getTopLeft(streak).dy));
      expect(tester.getTopLeft(streak).dy,
          lessThan(tester.getTopLeft(greeting).dy));
      // Should NOT show error
      expect(find.text('데이터를 불러올 수 없습니다'), findsNothing);
    });
  });
}
