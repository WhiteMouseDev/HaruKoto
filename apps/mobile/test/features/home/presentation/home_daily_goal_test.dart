import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/core/providers/study_clock_provider.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';
import 'package:harukoto_mobile/features/home/data/models/user_profile_model.dart';
import 'package:harukoto_mobile/features/home/presentation/home_page.dart';
import 'package:harukoto_mobile/features/home/providers/home_provider.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
      'home never reuses a completed ring during refresh, error or KST rollover',
      (tester) async {
    SharedPreferences.setMockInitialValues({'user_daily_goal': 20});
    final prefs = await SharedPreferences.getInstance();
    var now = DateTime.utc(2026, 10, 30, 14);
    var response = Future.value(_dashboard('2026-10-30', 20));
    var requests = 0;
    final container = ProviderContainer(overrides: [
      currentAccountIdProvider.overrideWithValue('account-a'),
      currentAccountReaderProvider.overrideWithValue(() => 'account-a'),
      sharedPreferencesProvider.overrideWithValue(prefs),
      studyClockProvider.overrideWithValue(() => now),
      dashboardProvider.overrideWith((ref) {
        ref.watch(studyDateProvider);
        requests++;
        return response;
      }),
      profileProvider.overrideWith((ref) async => const UserProfileModel(
          nickname: 'Test', dailyGoal: 20, showKana: false, jlptLevel: 'N5')),
      missionsProvider.overrideWith((ref) async => []),
      incompleteQuizProvider.overrideWith((ref) async => null),
    ]);
    try {
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomePage()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('오늘 20/20개'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);

      final failed = Completer<DashboardModel>();
      response = failed.future;
      container.invalidate(dashboardProvider);
      await tester.pump();
      expect(find.text('오늘 20/20개'), findsNothing);
      expect(find.text('100%'), findsNothing);
      expect(find.text('오늘 학습량 확인 필요'), findsOneWidget);
      failed.completeError(StateError('synthetic unavailable dashboard'));
      await tester.pumpAndSettle();
      expect(find.text('오늘 학습량 확인 필요'), findsOneWidget);
      expect(find.text('100%'), findsNothing);

      response = Future.value(_dashboard('2026-10-30', 8));
      container.invalidate(dashboardProvider);
      await tester.pumpAndSettle();
      expect(find.text('오늘 8/20개'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);

      now = DateTime.utc(2026, 10, 30, 15);
      container.read(studyDateProvider.notifier).refresh();
      await tester.pumpAndSettle();
      expect(requests, 4);
      // Even a successful stale server response cannot become the new day.
      expect(find.text('오늘 8/20개'), findsNothing);
      expect(find.text('40%'), findsNothing);
      expect(find.text('오늘 학습량 확인 필요'), findsOneWidget);

      response = Future.value(_dashboard('2026-10-31', 0));
      container.invalidate(dashboardProvider);
      await tester.pumpAndSettle();
      expect(find.text('오늘 0/20개'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    }
  });

  testWidgets('home rejects a late response after the account reader changes',
      (tester) async {
    SharedPreferences.setMockInitialValues({'user_daily_goal': 20});
    final prefs = await SharedPreferences.getInstance();
    var account = 'account-a';
    final pending = Completer<DashboardModel>();
    final container = ProviderContainer(overrides: [
      currentAccountIdProvider.overrideWithValue('account-a'),
      currentAccountReaderProvider.overrideWithValue(() => account),
      sharedPreferencesProvider.overrideWithValue(prefs),
      studyClockProvider.overrideWithValue(() => DateTime.utc(2026, 10, 30)),
      dashboardProvider.overrideWith((ref) => pending.future),
      profileProvider.overrideWith((ref) async => const UserProfileModel(
          nickname: 'Test', dailyGoal: 20, showKana: false, jlptLevel: 'N5')),
      missionsProvider.overrideWith((ref) async => []),
      incompleteQuizProvider.overrideWith((ref) async => null),
    ]);
    try {
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomePage()),
      ));
      await tester.pump();
      account = 'account-b';
      pending.complete(_dashboard('2026-10-30', 20));
      await tester.pumpAndSettle();
      expect(find.text('오늘 20/20개'), findsNothing);
      expect(find.text('100%'), findsNothing);
      expect(find.text('오늘 학습량 확인 필요'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    }
  });
}

DashboardModel _dashboard(String date, int count) => DashboardModel.fromJson({
      'today': {
        'vocabularyGoal': {'date': date, 'answeredCount': count},
      },
    });
