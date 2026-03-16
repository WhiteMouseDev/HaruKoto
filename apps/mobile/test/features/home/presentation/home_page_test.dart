import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';
import 'package:harukoto_mobile/features/home/data/models/mission_model.dart';
import 'package:harukoto_mobile/features/home/data/models/user_profile_model.dart';
import 'package:harukoto_mobile/features/home/presentation/home_page.dart';
import 'package:harukoto_mobile/features/home/providers/home_provider.dart';

void main() {
  group('HomePage', () {
    testWidgets('shows skeleton when all providers are loading',
        (tester) async {
      // Use completers that never complete to simulate loading
      final dashboardCompleter = Completer<DashboardModel>();
      final profileCompleter = Completer<UserProfileModel>();
      final missionsCompleter = Completer<List<MissionModel>>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
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
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
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

      // Should show the nickname from profile (rendered as '안녕, TestUser!')
      expect(find.text('안녕, TestUser!'), findsOneWidget);
      // Should NOT show error
      expect(find.text('데이터를 불러올 수 없습니다'), findsNothing);
    });
  });
}
