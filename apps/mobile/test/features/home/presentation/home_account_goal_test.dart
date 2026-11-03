import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/core/providers/study_clock_provider.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';
import 'package:harukoto_mobile/features/home/presentation/home_page.dart';
import 'package:harukoto_mobile/features/home/providers/home_provider.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('B profile failure never uses A goal or a default as confirmed',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'user_daily_goal': 20, 'user_daily_goal_v2:a': 20});
    final prefs = await SharedPreferences.getInstance();
    final container = _container(prefs);
    try {
      await tester.pumpWidget(UncontrolledProviderScope(
          container: container, child: const MaterialApp(home: HomePage())));
      await tester.pumpAndSettle();
      expect(find.text('오늘 10/20개'), findsNothing);
      expect(find.text('50%'), findsNothing);
      expect(find.text('0%'), findsNothing);
      expect(find.text('오늘 학습량 확인 필요'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    }
  });

  testWidgets(
      'B confirmed goal restores after a fresh container with failed profile',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'user_daily_goal': 20,
      'user_daily_goal_v2:a': 20,
      'user_daily_goal_v2:b': 30
    });
    final prefs = await SharedPreferences.getInstance();
    for (var launch = 0; launch < 2; launch++) {
      final container = _container(prefs);
      try {
        await tester.pumpWidget(UncontrolledProviderScope(
            container: container, child: const MaterialApp(home: HomePage())));
        await tester.pumpAndSettle();
        expect(find.text('오늘 10/30개'), findsOneWidget);
        expect(find.text('33%'), findsOneWidget);
        expect(find.text('50%'), findsNothing);
      } finally {
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      }
    }
  });
}

ProviderContainer _container(SharedPreferences prefs) =>
    ProviderContainer(overrides: [
      currentAccountIdProvider.overrideWithValue('b'),
      currentAccountReaderProvider.overrideWithValue(() => 'b'),
      sharedPreferencesProvider.overrideWithValue(prefs),
      studyClockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 3)),
      dashboardProvider.overrideWith((ref) async => DashboardModel.fromJson({
            'today': {
              'vocabularyGoal': {'date': '2026-11-03', 'answeredCount': 10}
            }
          })),
      profileProvider.overrideWith(
          (ref) => Future.error(StateError('Profile unavailable'))),
      missionsProvider.overrideWith((ref) async => []),
      incompleteQuizProvider.overrideWith((ref) async => null),
    ]);
