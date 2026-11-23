import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/current_account_provider.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/providers/study_clock_provider.dart';
import '../../../core/providers/user_preferences_provider.dart';
import '../../../shared/widgets/app_error_retry.dart';
import '../../../shared/widgets/app_segmented_tabs.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../home/data/models/dashboard_model.dart';
import '../../home/providers/home_provider.dart';
import '../data/models/level_progress_model.dart' as stats;
import '../data/models/stats_history_model.dart';
import '../providers/stats_provider.dart';
import 'widgets/period_tab.dart';
import 'widgets/study_tab.dart';
import 'widgets/jlpt_tab.dart';

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  int _selectedTab = 0;
  late int _heatmapYear;

  @override
  void initState() {
    super.initState();
    _heatmapYear = ref.read(studyDateProvider).year;
  }

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(currentAccountIdProvider);
    final accountCurrent =
        owner != null && ref.watch(currentAccountReaderProvider)() == owner;
    final dashboardAsync = ref.watch(dashboardProvider);
    final historyAsync = ref.watch(statsHistoryProvider(_heatmapYear));
    final jlptLevel = ref.watch(userPreferencesProvider).jlptLevel;

    // Multi-provider composition: manual AsyncValue handling is used instead
    // of .when() because loading/error states are combined across providers.
    final allLoading =
        !accountCurrent || dashboardAsync.isLoading || historyAsync.isLoading;

    if (allLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('학습 통계')),
        body: const AppSkeleton(
          itemCount: 4,
          itemHeights: [48, 140, 140, 140],
        ),
      );
    }

    // A failed history request must not look like an empty study calendar.
    if (dashboardAsync.hasError || historyAsync.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('학습 통계')),
        body: AppErrorRetry(onRetry: () {
          ref.invalidate(dashboardProvider);
          ref.invalidate(statsHistoryProvider(_heatmapYear));
        }),
      );
    }

    final dashboard = dashboardAsync.hasValue ? dashboardAsync.value : null;
    final historyRecords =
        historyAsync.hasValue ? historyAsync.value! : <StatsHistoryRecord>[];

    // JLPT progress fallback — actual data is fetched via jlptProgressProvider
    // inside JlptTab and StudyTab widgets directly.
    const levelProgress = stats.LevelProgressData(
      vocabulary: stats.ProgressCategory(total: 0, mastered: 0, inProgress: 0),
      grammar: stats.ProgressCategory(total: 0, mastered: 0, inProgress: 0),
    );

    const tabLabels = ['기간별', '학습별', 'JLPT 진도'];

    return Scaffold(
      appBar: AppBar(title: const Text('학습 통계')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.md, 0, AppSizes.md, AppSizes.sm),
            child: AppSegmentedTabs(
              labels: tabLabels,
              selectedIndex: _selectedTab,
              onChanged: (index) => setState(() => _selectedTab = index),
            ),
          ),

          // Scrollable tab content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
              children: [
                if (_selectedTab == 0)
                  PeriodTab(
                    today: dashboard?.today ??
                        const TodayStats(
                          wordsStudied: 0,
                          quizzesCompleted: 0,
                          correctAnswers: 0,
                          totalAnswers: 0,
                          xpEarned: 0,
                          goalProgress: 0.0,
                          hasStudied: false,
                        ),
                    historyRecords: historyRecords,
                    heatmapYear: _heatmapYear,
                    onHeatmapYearChange: (year) {
                      setState(() => _heatmapYear = year);
                    },
                  ),
                if (_selectedTab == 1)
                  StudyTab(
                    levelProgress: levelProgress,
                    historyRecords: historyRecords,
                  ),
                if (_selectedTab == 2)
                  JlptTab(
                    levelProgress: levelProgress,
                    currentLevel: jlptLevel,
                  ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
