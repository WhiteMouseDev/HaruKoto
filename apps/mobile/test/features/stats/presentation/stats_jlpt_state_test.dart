import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/network/connectivity_service.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/core/providers/study_clock_provider.dart';
import 'package:harukoto_mobile/core/providers/user_preferences_provider.dart';
import 'package:harukoto_mobile/core/router/app_router.dart';
import 'package:harukoto_mobile/features/auth/providers/auth_provider.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';
import 'package:harukoto_mobile/features/home/providers/home_provider.dart';
import 'package:harukoto_mobile/features/home/providers/study_activity_refresh_provider.dart';
import 'package:harukoto_mobile/features/stats/data/models/heatmap_data_model.dart';
import 'package:harukoto_mobile/features/stats/data/models/level_progress_model.dart';
import 'package:harukoto_mobile/features/stats/data/models/time_chart_model.dart';
import 'package:harukoto_mobile/features/stats/data/stats_repository.dart';
import 'package:harukoto_mobile/features/stats/presentation/stats_page.dart';
import 'package:harukoto_mobile/features/stats/presentation/widgets/jlpt_tab.dart';
import 'package:harukoto_mobile/features/stats/providers/stats_provider.dart';
import 'package:harukoto_mobile/shared/widgets/bottom_nav.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('JLPT retries a failed request and refreshes after studying',
      (tester) async {
    final dio = Dio();
    addTearDown(dio.close);
    var requests = 0;
    var mastered = 0;
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests++;
      if (requests == 1) {
        handler.reject(DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ));
        return;
      }
      handler.resolve(Response(requestOptions: options, data: {
        'levels': [
          {
            'level': 'N4',
            'vocabulary': {'total': 10, 'mastered': mastered, 'inProgress': 0},
            'grammar': {'total': 10, 'mastered': 0, 'inProgress': 0},
          },
        ],
      }));
    }));
    final container = ProviderContainer(retry: (_, __) => null, overrides: [
      currentAccountIdProvider.overrideWithValue('test-account'),
      statsRepositoryProvider.overrideWithValue(StatsRepository(dio)),
    ]);
    try {
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: JlptTab(currentLevel: 'N4')),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('급수별 진도를 불러오지 못했어요'), findsOneWidget);
      expect(find.text('N4 진도 정보가 아직 없어요'), findsNothing);

      await tester.tap(find.text('다시 시도'));
      await tester.pumpAndSettle();
      expect(find.text('N4 난이도', findRichText: true), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);

      mastered = 5;
      container.read(studyActivityRefreshProvider).refresh();
      await tester.pumpAndSettle();
      expect(requests, 3);
      expect(find.text('25%'), findsOneWidget);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    }
  });

  testWidgets('JLPT tabs change only the summary and reopen at the saved level',
      (tester) async {
    SharedPreferences.setMockInitialValues({'user_jlpt_level': 'N4'});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(retry: (_, __) => null, overrides: [
      currentAccountIdProvider.overrideWithValue('test-account'),
      currentAccountReaderProvider.overrideWithValue(() => 'test-account'),
      isAuthenticatedProvider.overrideWithValue(true),
      connectivityProvider.overrideWith((ref) => Stream.value(true)),
      sharedPreferencesProvider.overrideWithValue(preferences),
      studyClockProvider.overrideWithValue(() => DateTime.utc(2026, 11, 23)),
      dashboardProvider
          .overrideWith((ref) async => DashboardModel.fromJson({})),
      statsHistoryProvider.overrideWith((ref, year) async => []),
      heatmapProvider
          .overrideWith((ref, year) async => const HeatmapResponse(data: [])),
      timeChartProvider
          .overrideWith((ref, days) async => const TimeChartResponse(data: [])),
      jlptProgressProvider.overrideWith((ref) async => _sampleProgress),
    ]);
    final router = container.read(routerProvider);
    router.go('/stats');

    try {
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(StatsPage), findsOneWidget);
      expect(tester.widget<BottomNav>(find.byType(BottomNav)).currentIndex, 0);
      await tester.tap(find.text('JLPT진도'));
      await tester.pumpAndSettle();
      expect(find.text('학습 진도 요약'), findsOneWidget);
      expect(find.text('N4 난이도', findRichText: true), findsOneWidget);
      expect(find.text('10%'), findsOneWidget);
      expect(find.textContaining('단어 850개, 문법 44개', findRichText: true),
          findsOneWidget);
      expect(find.text('전체 레벨 진도'), findsNothing);
      expect(find.text('문장배열'), findsNothing);
      expect(
          find.byKey(const ValueKey('jlpt-progress-summary')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('jlpt-progress-tab-N2')));
      await tester.pumpAndSettle();
      expect(find.text('N2 난이도', findRichText: true), findsOneWidget);
      expect(find.text('11%'), findsOneWidget);
      expect(find.textContaining('단어 270개, 문법 40개', findRichText: true),
          findsOneWidget);
      expect(find.text('N4 난이도', findRichText: true), findsNothing);
      expect(find.text('다음 목표는 N3', findRichText: true), findsOneWidget);
      expect(container.read(userPreferencesProvider).jlptLevel, 'N4');
      await preferences.reload();
      expect(preferences.getString('user_jlpt_level'), 'N4');

      await tester.tap(find.byKey(const ValueKey('jlpt-progress-tab-N3')));
      await tester.pumpAndSettle();
      expect(find.text('N3 난이도', findRichText: true), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(find.textContaining('단어 350개, 문법 60개', findRichText: true),
          findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('jlpt-progress-tab-N1')));
      await tester.pumpAndSettle();
      expect(find.text('N1 진도 정보가 아직 없어요'), findsOneWidget);
      expect(find.text('0%'), findsNothing);

      await tester.tap(find.text('기간별'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('JLPT진도'));
      await tester.pumpAndSettle();
      expect(find.text('N4 난이도', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    }
  });
}

const _sampleProgress = JlptProgressResponse(levels: [
  JlptLevelProgress(
    level: 'N4',
    vocabulary: ProgressCategory(total: 944, mastered: 94, inProgress: 0),
    grammar: ProgressCategory(total: 49, mastered: 5, inProgress: 0),
  ),
  JlptLevelProgress(
    level: 'N3',
    vocabulary: ProgressCategory(total: 350, mastered: 0, inProgress: 0),
    grammar: ProgressCategory(total: 60, mastered: 0, inProgress: 0),
  ),
  JlptLevelProgress(
    level: 'N2',
    vocabulary: ProgressCategory(total: 300, mastered: 30, inProgress: 0),
    grammar: ProgressCategory(total: 50, mastered: 10, inProgress: 0),
  ),
]);
