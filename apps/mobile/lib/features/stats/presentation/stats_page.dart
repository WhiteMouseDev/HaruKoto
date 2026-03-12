import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/sizes.dart';
import '../../../shared/widgets/app_error_retry.dart';
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

class _StatsPageState extends ConsumerState<StatsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _heatmapYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardAsync = ref.watch(dashboardProvider);
    final profileAsync = ref.watch(profileProvider);
    final historyAsync = ref.watch(statsHistoryProvider(_heatmapYear));

    // Show skeleton only when all are still in initial loading
    final allLoading = dashboardAsync.isLoading &&
        profileAsync.isLoading &&
        historyAsync.isLoading;

    if (allLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('학습 통계')),
        body: const AppSkeleton(
          itemCount: 4,
          itemHeights: [48, 140, 140, 140],
        ),
      );
    }

    // Show error if main data failed and no fallback available
    final hasAnyError = dashboardAsync.hasError || profileAsync.hasError;
    final hasAnyValue = dashboardAsync.hasValue || profileAsync.hasValue;

    if (hasAnyError && !hasAnyValue) {
      return Scaffold(
        appBar: AppBar(title: const Text('학습 통계')),
        body: AppErrorRetry(onRetry: () {
          ref.invalidate(dashboardProvider);
          ref.invalidate(profileProvider);
          ref.invalidate(statsHistoryProvider(_heatmapYear));
        }),
      );
    }

    final dashboard = dashboardAsync.hasValue ? dashboardAsync.value : null;
    final profile = profileAsync.hasValue ? profileAsync.value : null;
    final historyRecords =
        historyAsync.hasValue ? historyAsync.value! : <StatsHistoryRecord>[];
    final jlptLevel = profile?.jlptLevel ?? 'N5';

    // TODO: levelProgress API 연동 필요 — 현재 백엔드 미구현으로 fallback
    const levelProgress = stats.LevelProgressData(
      vocabulary: stats.ProgressCategory(total: 0, mastered: 0, inProgress: 0),
      grammar: stats.ProgressCategory(total: 0, mastered: 0, inProgress: 0),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('학습 통계'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '기간별'),
            Tab(text: '학습별'),
            Tab(text: 'JLPT 진도'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.md),
            child: PeriodTab(
              today: dashboard?.today ??
                  const TodayStats(
                    wordsStudied: 0,
                    quizzesCompleted: 0,
                    correctAnswers: 0,
                    totalAnswers: 0,
                    xpEarned: 0,
                    goalProgress: 0.0,
                  ),
              historyRecords: historyRecords,
              heatmapYear: _heatmapYear,
              onHeatmapYearChange: (year) {
                setState(() => _heatmapYear = year);
              },
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.md),
            child: StudyTab(
              levelProgress: levelProgress,
              historyRecords: historyRecords,
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.md),
            child: JlptTab(
              levelProgress: levelProgress,
              currentLevel: jlptLevel,
            ),
          ),
        ],
      ),
    );
  }

}
