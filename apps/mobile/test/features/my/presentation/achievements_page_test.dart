import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/network/connectivity_service.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/core/router/app_router.dart';
import 'package:harukoto_mobile/features/auth/providers/auth_provider.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';
import 'package:harukoto_mobile/features/home/data/models/user_profile_model.dart';
import 'package:harukoto_mobile/features/home/presentation/home_page.dart';
import 'package:harukoto_mobile/features/home/providers/home_provider.dart';
import 'package:harukoto_mobile/features/my/data/models/achievement_model.dart';
import 'package:harukoto_mobile/features/my/presentation/achievements_page.dart';
import 'package:harukoto_mobile/features/my/providers/my_provider.dart';
import 'package:harukoto_mobile/features/notifications/data/models/notification_model.dart';
import 'package:harukoto_mobile/features/notifications/providers/notification_provider.dart';
import 'package:harukoto_mobile/shared/widgets/bottom_nav.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('catalog drives three columns, counts and achievement dates',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          achievementsProvider.overrideWith((ref) async => _catalog),
        ],
        child: MaterialApp(
          theme: ThemeData.dark(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
            ),
            child: child!,
          ),
          home: const AchievementsPage(),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('1개 달성'), findsOneWidget);
      expect(find.text('1 / 4'), findsOneWidget);
      expect(find.text('2026.11.24'), findsOneWidget);
      expect(find.bySemanticsLabel('첫 퀴즈 완료!, 달성, 2026.11.24'), findsOneWidget);
      expect(find.bySemanticsLabel('퀴즈 10회 달성, 미달성'), findsOneWidget);
      final first = tester.getTopLeft(find.text(_catalog[0].title));
      final second = tester.getTopLeft(find.text(_catalog[1].title));
      final third = tester.getTopLeft(find.text(_catalog[2].title));
      expect(first.dx, lessThan(second.dx));
      expect(second.dx, lessThan(third.dx));
      expect(first.dy, second.dy);
      expect(second.dy, third.dy);
      await tester.ensureVisible(find.text(_catalog[3].title));
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('loading and failure offer no fake badges and retry works',
      (tester) async {
    final initial = Completer<List<AchievementItem>>();
    var requests = 0;
    final scope = ProviderContainer(retry: (_, __) => null, overrides: [
      achievementsProvider.overrideWith((ref) {
        requests++;
        return requests == 1 ? initial.future : Future.value([]);
      }),
    ]);
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(UncontrolledProviderScope(
        container: scope,
        child: const MaterialApp(home: AchievementsPage()),
      ));
      expect(find.bySemanticsLabel('도전과제를 불러오는 중'), findsOneWidget);
      expect(find.text('0개 달성'), findsNothing);

      initial.completeError(StateError('read failed'));
      await tester.pumpAndSettle();
      expect(find.text('도전과제를 불러올 수 없습니다'), findsOneWidget);
      expect(find.text('아직 표시할 도전과제가 없어요.'), findsNothing);

      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(requests, 2);
      expect(find.text('아직 표시할 도전과제가 없어요.'), findsOneWidget);
      expect(find.text('도전과제를 불러올 수 없습니다'), findsNothing);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
      scope.dispose();
    }
  });

  testWidgets('home shortcut opens the full tab child and back restores home',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final scope = ProviderContainer(retry: (_, __) => null, overrides: [
      currentAccountIdProvider.overrideWithValue('test-account'),
      currentAccountReaderProvider.overrideWithValue(() => 'test-account'),
      isAuthenticatedProvider.overrideWithValue(true),
      connectivityProvider.overrideWith((ref) => Stream.value(true)),
      sharedPreferencesProvider.overrideWithValue(preferences),
      dashboardProvider
          .overrideWith((ref) async => DashboardModel.fromJson({})),
      profileProvider.overrideWith((ref) async => const UserProfileModel(
            nickname: 'Test',
            dailyGoal: 10,
            showKana: false,
            jlptLevel: 'N5',
          )),
      missionsProvider.overrideWith((ref) async => []),
      notificationsProvider.overrideWith(
        (ref) async => const NotificationsResponse(
          notifications: [],
          unreadCount: 0,
        ),
      ),
      achievementsProvider.overrideWith((ref) async => _catalog),
    ]);
    final router = scope.read(routerProvider);
    router.go('/home');

    try {
      await tester.pumpWidget(UncontrolledProviderScope(
        container: scope,
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      final shortcut = find.text('도전과제');
      await tester.scrollUntilVisible(shortcut, 280);
      await tester.pumpAndSettle();
      await tester.tap(shortcut.hitTestable());
      await tester.pumpAndSettle();

      expect(find.byType(AchievementsPage), findsOneWidget);
      expect(tester.widget<BottomNav>(find.byType(BottomNav)).currentIndex, 0);
      expect(find.byType(BottomNav).hitTestable(), findsOneWidget);
      await tester.tap(find.widgetWithIcon(IconButton, LucideIcons.arrowLeft));
      await tester.pumpAndSettle();
      expect(find.byType(AchievementsPage), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);
      expect(tester.widget<BottomNav>(find.byType(BottomNav)).currentIndex, 0);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      scope.dispose();
    }
  });
}

const _catalog = [
  AchievementItem(
    type: 'first_quiz',
    title: '첫 퀴즈 완료!',
    description: '첫 번째 퀴즈를 완료했어요',
    emoji: 'target',
    achieved: true,
    achievedAt: '2026-11-24T02:00:00Z',
  ),
  AchievementItem(
    type: 'quiz_10',
    title: '퀴즈 10회 달성',
    description: '퀴즈를 10번 완료했어요',
    emoji: 'file-text',
    achieved: false,
  ),
  AchievementItem(
    type: 'quiz_50',
    title: '퀴즈 50회 달성',
    description: '퀴즈를 50번 완료했어요',
    emoji: 'library',
    achieved: false,
  ),
  AchievementItem(
    type: 'streak_100',
    title: '100일 연속 학습 도전과제',
    description: '100일 연속으로 학습했어요',
    emoji: 'crown',
    achieved: false,
  ),
];
