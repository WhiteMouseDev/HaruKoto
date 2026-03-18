import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/providers/quiz_settings_provider.dart';
import '../../../shared/widgets/app_error_retry.dart';
import 'widgets/home_skeleton.dart';
import '../providers/home_provider.dart';
import 'widgets/daily_missions_card.dart';
import 'widgets/home_header.dart';
import 'widgets/kana_cta_card.dart';
// import 'widgets/phone_call_cta.dart'; // 주석 처리 — 추후 다시 활성화 가능
import 'widgets/quick_start_card.dart';
import 'widgets/streak_daily_card.dart';
import 'widgets/shortcut_grid.dart';
import 'widgets/weekly_chart.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _staggerController;
  bool _hasAnimated = false;
  bool _animationScheduled = false;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Widget _staggered(int index, Widget child) {
    if (_hasAnimated) return child;

    final start = (index * 0.12).clamp(0.0, 0.7);
    final end = (start + 0.4).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, _) {
        final t = Interval(start, end, curve: Curves.easeOutCubic)
            .transform(_staggerController.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }

  void _refresh() {
    ref.invalidate(dashboardProvider);
    ref.invalidate(profileProvider);
    ref.invalidate(missionsProvider);
  }

  @override
  Widget build(BuildContext context) {
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
        body: SafeArea(child: HomeSkeleton()),
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
          child: AppErrorRetry(onRetry: _refresh),
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

    // Trigger stagger animation on first data load
    if (!_hasAnimated && !_animationScheduled) {
      _animationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasAnimated) {
          _staggerController.forward().then((_) {
            if (mounted) setState(() => _hasAnimated = true);
          });
        }
      });
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: Theme.of(context).colorScheme.primary,
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: const EdgeInsets.only(top: 12, bottom: 32),
            children: [
              // 1. Header
              _staggered(
                  0, HomeHeader(nickname: profile?.nickname ?? '학습자')),
              const SizedBox(height: AppSizes.md),

              // 2. AI Phone Call CTA (주석 처리 — 추후 다시 활성화 가능)
              // const PhoneCallCta(),
              // const SizedBox(height: AppSizes.md),

              // 3. Kana CTA (conditional)
              if (profile?.showKana == true &&
                  dashboard?.kanaProgress != null &&
                  !dashboard!.kanaProgress!.completed) ...[
                _staggered(
                    1, KanaCtaCard(kanaProgress: dashboard.kanaProgress!)),
                const SizedBox(height: AppSizes.md),
              ],

              // 4. Streak + Daily Stats
              if (dashboard != null) ...[
                _staggered(
                  2,
                  StreakDailyCard(
                    streak: dashboard.streak,
                    today: dashboard.today,
                    weeklyStats: dashboard.weeklyStats,
                    dailyGoal: profile?.dailyGoal ?? 10,
                  ),
                ),
                const SizedBox(height: AppSizes.md),
              ],

              // 5. Study Card with category tabs
              _staggered(
                3,
                QuickStartCard(
                  levelProgress: dashboard?.levelProgress,
                  today: dashboard?.today,
                  dailyGoal: profile?.dailyGoal ?? 10,
                  jlptLevel: profile?.jlptLevel ?? 'N5',
                ),
              ),
              const SizedBox(height: AppSizes.md),

              // 6. Daily Missions
              if (missions != null && missions.isNotEmpty) ...[
                _staggered(4, DailyMissionsCard(missions: missions)),
                const SizedBox(height: AppSizes.md),
              ],

              // 7. Weekly Chart
              if (dashboard != null && dashboard.weeklyStats.isNotEmpty)
                _staggered(
                  5,
                  WeeklyChart(
                    weeklyStats: dashboard.weeklyStats,
                    dailyGoal: profile?.dailyGoal ?? 10,
                  ),
                ),
              const SizedBox(height: AppSizes.md),

              // 8. Shortcut Grid
              _staggered(6, const ShortcutGrid()),
            ],
          ),
        ),
      ),
    );
  }
}
