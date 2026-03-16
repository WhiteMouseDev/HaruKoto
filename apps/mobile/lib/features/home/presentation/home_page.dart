import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/providers/quiz_settings_provider.dart';
import '../../../shared/widgets/app_error_retry.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../providers/home_provider.dart';
import 'widgets/daily_missions_card.dart';
import 'widgets/home_header.dart';
import 'widgets/kana_cta_card.dart';
// import 'widgets/phone_call_cta.dart'; // 주석 처리 — 추후 다시 활성화 가능
import 'widgets/quick_start_card.dart';
import 'widgets/streak_daily_card.dart';
import 'widgets/shortcut_grid.dart';
import 'widgets/weekly_chart.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  void _refresh(WidgetRef ref) {
    ref.invalidate(dashboardProvider);
    ref.invalidate(profileProvider);
    ref.invalidate(missionsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final profileAsync = ref.watch(profileProvider);
    final missionsAsync = ref.watch(missionsProvider);

    // Multi-provider composition: manual AsyncValue handling is used instead
    // of .when() because loading/error states are combined across 3 providers.
    final allLoading = dashboardAsync.isLoading &&
        profileAsync.isLoading &&
        missionsAsync.isLoading;

    if (allLoading) {
      return const Scaffold(
        body: SafeArea(child: AppSkeleton()),
      );
    }

    // Show error if ANY provider has error and NO provider has data yet
    final hasAnyError = dashboardAsync.hasError ||
        profileAsync.hasError ||
        missionsAsync.hasError;
    final hasAnyValue = dashboardAsync.hasValue ||
        profileAsync.hasValue ||
        missionsAsync.hasValue;

    if (hasAnyError && !hasAnyValue) {
      return Scaffold(
        body: SafeArea(
          child: AppErrorRetry(onRetry: () => _refresh(ref)),
        ),
      );
    }

    final dashboard = dashboardAsync.hasValue ? dashboardAsync.value : null;
    final profile = profileAsync.hasValue ? profileAsync.value : null;
    final missions = missionsAsync.hasValue ? missionsAsync.value : null;

    // Sync furigana setting from server on profile load
    if (profile != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(quizSettingsProvider.notifier).setShowFurigana(
              profile.showFurigana,
            );
      });
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: Theme.of(context).colorScheme.primary,
          onRefresh: () async => _refresh(ref),
          child: ListView(
            padding: const EdgeInsets.only(top: 12, bottom: 32),
            children: [
              // 1. Header
              HomeHeader(nickname: profile?.nickname ?? '학습자'),
              const SizedBox(height: AppSizes.md),

              // 2. AI Phone Call CTA (주석 처리 — 추후 다시 활성화 가능)
              // const PhoneCallCta(),
              // const SizedBox(height: AppSizes.md),

              // 3. Kana CTA (conditional)
              if (profile?.showKana == true &&
                  dashboard?.kanaProgress != null &&
                  !dashboard!.kanaProgress!.completed) ...[
                KanaCtaCard(kanaProgress: dashboard.kanaProgress!),
                const SizedBox(height: AppSizes.md),
              ],

              // 4. Streak + Daily Stats
              if (dashboard != null) ...[
                StreakDailyCard(
                  streak: dashboard.streak,
                  today: dashboard.today,
                  weeklyStats: dashboard.weeklyStats,
                  dailyGoal: profile?.dailyGoal ?? 10,
                ),
                const SizedBox(height: AppSizes.md),
              ],

              // 5. Daily Missions
              if (missions != null && missions.isNotEmpty) ...[
                DailyMissionsCard(missions: missions),
                const SizedBox(height: AppSizes.md),
              ],

              // 6. Study Card with category tabs
              QuickStartCard(
                levelProgress: dashboard?.levelProgress,
                today: dashboard?.today,
                dailyGoal: profile?.dailyGoal ?? 10,
              ),
              const SizedBox(height: AppSizes.md),

              // 7. Weekly Chart
              if (dashboard != null && dashboard.weeklyStats.isNotEmpty)
                WeeklyChart(
                  weeklyStats: dashboard.weeklyStats,
                  dailyGoal: profile?.dailyGoal ?? 10,
                ),
              const SizedBox(height: AppSizes.md),

              // 8. Shortcut Grid
              const ShortcutGrid(),
            ],
          ),
        ),
      ),
    );
  }
}
