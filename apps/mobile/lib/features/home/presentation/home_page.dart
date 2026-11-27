import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/current_account_provider.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/providers/study_clock_provider.dart';
import '../../study/presentation/widgets/saved_quiz_section.dart';
import '../../../core/providers/user_preferences_provider.dart';
import '../../study/providers/quiz_progress_refresh_provider.dart';
import '../../study/providers/lesson_activity_sync_provider.dart';
import '../../study/presentation/widgets/lesson_activity_pending_banner.dart';
import '../../../shared/widgets/app_error_retry.dart';
import 'widgets/home_skeleton.dart';
import '../providers/home_provider.dart';
import '../providers/study_activity_refresh_provider.dart';
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
    final animate = !_hasAnimated &&
        _animationScheduled &&
        !MediaQuery.disableAnimationsOf(context);
    final start = (index * 0.12).clamp(0.0, 0.7);
    final end = (start + 0.4).clamp(0.0, 1.0);

    return AnimatedBuilder(
      animation: _staggerController,
      child: child,
      builder: (context, child) {
        final t = animate
            ? Interval(start, end, curve: Curves.easeOutCubic)
                .transform(_staggerController.value)
            : 1.0;
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
    ref.read(quizProgressRefreshProvider).refresh();
    ref.read(studyActivityRefreshProvider).refresh();
    ref.invalidate(profileProvider);
    ref.invalidate(missionsProvider);
    unawaited(ref.read(lessonActivitySyncProvider.notifier).sync());
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(currentAccountIdProvider);
    final accountCurrent =
        owner != null && ref.watch(currentAccountReaderProvider)() == owner;
    final dashboardAsync = ref.watch(dashboardProvider);
    final profileAsync = ref.watch(profileProvider);
    final missionsAsync = ref.watch(missionsProvider);
    final preferences = ref.watch(userPreferencesProvider);
    final studyDate = ref.watch(studyDateProvider);

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
          child: Column(children: [
            const LessonActivityPendingBanner(),
            Expanded(child: AppErrorRetry(onRetry: _refresh)),
          ]),
        ),
      );
    }

    // Never present yesterday's completion as today's while a date/resume
    // refresh is pending or has failed.
    final dashboard =
        accountCurrent && !dashboardAsync.isLoading && !dashboardAsync.hasError
            ? dashboardAsync.value
            : null;
    final dashboardLoading = dashboardAsync.isLoading;
    final profile = profileAsync.hasValue ? profileAsync.value : null;
    final missions = missionsAsync.hasValue ? missionsAsync.value : null;

    // Trigger stagger animation on first data load
    if (dashboard != null && !_hasAnimated && !_animationScheduled) {
      _animationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasAnimated) {
          _staggerController.forward().then((_) {
            if (mounted) setState(() => _hasAnimated = true);
          });
        }
      });
    }

    final topInset = MediaQuery.paddingOf(context).top;
    final minimumTopInset =
        Theme.of(context).platform == TargetPlatform.iOS && topInset >= 44
            ? 54.0
            : 0.0;

    return Scaffold(
      body: SafeArea(
        minimum: EdgeInsets.only(top: minimumTopInset),
        child: RefreshIndicator(
          color: Theme.of(context).colorScheme.primary,
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 72),
            children: [
              const HomeTitleBar(),
              const LessonActivityPendingBanner(),
              const SizedBox(height: AppSizes.sm),
              if (dashboard != null) ...[
                _staggered(
                  0,
                  StreakDailyCard(
                    streak: dashboard.streak,
                    today: dashboard.today,
                    weeklyStats: dashboard.weeklyStats,
                    dailyGoal: preferences.dailyGoalConfirmed
                        ? preferences.dailyGoal
                        : 0,
                  ),
                ),
              ] else if (dashboardLoading)
                const HomeStreakSkeleton()
              else
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.pageHorizontal, vertical: 16),
                  child: Column(
                    children: [
                      const Text('학습 기록을 확인하지 못했어요'),
                      TextButton(
                        style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48)),
                        onPressed: _refresh,
                        child: const Text('다시 확인'),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSizes.lg),
              if (profile == null && profileAsync.isLoading)
                const HomeGreetingSkeleton()
              else
                _staggered(1, HomeHeader(nickname: profile?.nickname ?? '학습자')),
              const SizedBox(height: 11),
              if (preferences.showKana &&
                  dashboard?.kanaProgress != null &&
                  !dashboard!.kanaProgress!.completed) ...[
                _staggered(
                    2, KanaCtaCard(kanaProgress: dashboard.kanaProgress!)),
                const SizedBox(height: AppSizes.md),
              ],
              _staggered(
                3,
                QuickStartCard(
                  today: dashboard?.today,
                  isLoading: dashboardLoading,
                  dailyGoal: preferences.dailyGoal,
                  dailyGoalKnown:
                      accountCurrent && preferences.dailyGoalConfirmed,
                  jlptLevel: preferences.jlptLevel,
                  showSavedQuiz: false,
                ),
              ),
              const SizedBox(height: AppSizes.xl),
              if (missions != null && missions.isNotEmpty) ...[
                _staggered(4, DailyMissionsCard(missions: missions)),
                const SizedBox(height: 40),
              ] else if (missions == null && missionsAsync.isLoading) ...[
                const DailyMissionsCard(missions: [], isLoading: true),
                const SizedBox(height: 40),
              ],
              _staggered(
                5,
                WeeklyChart(
                  key: ValueKey(owner),
                  weeklyStats: dashboard?.weeklyStats ?? const [],
                  questionStats: dashboard?.weeklyQuestionStats,
                  studyDate: studyDate,
                  isLoading: dashboardLoading,
                  hasError: dashboardAsync.hasError,
                ),
              ),
              const SizedBox(height: 33),
              _staggered(6, const ShortcutGrid()),
              const SavedQuizSection(
                compact: true,
                padding: EdgeInsets.fromLTRB(20, 32, 20, 0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
