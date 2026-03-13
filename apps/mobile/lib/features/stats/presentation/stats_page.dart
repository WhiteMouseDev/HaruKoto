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

class _StatsPageState extends ConsumerState<StatsPage> {
  int _selectedTab = 0;
  int _heatmapYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dashboardAsync = ref.watch(dashboardProvider);
    final profileAsync = ref.watch(profileProvider);
    final historyAsync = ref.watch(statsHistoryProvider(_heatmapYear));

    // Multi-provider composition: manual AsyncValue handling is used instead
    // of .when() because loading/error states are combined across 3 providers.
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

    const tabLabels = ['기간별', '학습별', 'JLPT 진도'];

    return Scaffold(
      appBar: AppBar(title: const Text('학습 통계')),
      body: Column(
        children: [
          // Fixed pill-style segmented tab
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.md, 0, AppSizes.md, AppSizes.sm),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: List.generate(tabLabels.length, (i) {
                  final isSelected = _selectedTab == i;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.surface
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          tabLabels[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
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
