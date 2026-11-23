import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/auth/current_account_provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/providers/study_clock_provider.dart';
import '../../../core/providers/user_preferences_provider.dart';
import '../../../core/theme/text_theme.dart';
import '../../../shared/widgets/app_error_retry.dart';
import '../../../shared/widgets/app_segmented_tabs.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../home/providers/home_provider.dart';
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
  int? _selectedHeatmapYear;

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(currentAccountIdProvider);
    final accountCurrent =
        owner != null && ref.watch(currentAccountReaderProvider)() == owner;
    if (!accountCurrent) {
      return Scaffold(
        appBar: _buildStatsAppBar(context),
        body: _skeleton,
      );
    }

    const tabLabels = ['기간별', '학습별', 'JLPT진도'];
    final content = switch (_selectedTab) {
      0 => _buildPeriod(owner),
      1 => _scroll(StudyTab(key: ValueKey(owner))),
      _ => _scroll(JlptTab(
          key: ValueKey(owner),
          currentLevel: ref.watch(userPreferencesProvider).jlptLevel,
        )),
    };

    return Scaffold(
      appBar: _buildStatsAppBar(context),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.pageHorizontal, 6, AppSizes.pageHorizontal, 20),
            child: AppSegmentedTabs(
              labels: tabLabels,
              compact: true,
              selectedIndex: _selectedTab,
              onChanged: (index) => setState(() => _selectedTab = index),
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              left: false,
              right: false,
              child: content,
            ),
          ),
        ],
      ),
    );
  }

  static const _skeleton = AppSkeleton(
    itemCount: 4,
    itemHeights: [48, 140, 140, 140],
  );

  Widget _scroll(Widget child) => ListView(
        key: ValueKey(_selectedTab),
        padding: const EdgeInsets.fromLTRB(
            AppSizes.pageHorizontal, 0, AppSizes.pageHorizontal, AppSizes.xl),
        children: [child],
      );

  Widget _buildPeriod(String? owner) {
    final currentYear = ref.watch(studyDateProvider).year;
    final year = _selectedHeatmapYear ?? currentYear;
    final dashboard = ref.watch(dashboardProvider);
    final history = ref.watch(statsHistoryProvider(year));
    if (dashboard.isLoading) return _skeleton;
    if (dashboard.hasError) {
      return AppErrorRetry(onRetry: () => ref.invalidate(dashboardProvider));
    }
    final snapshot = dashboard.requireValue;
    return _scroll(PeriodTab(
      key: ValueKey(owner),
      today: snapshot.today,
      questionStats: snapshot.weeklyQuestionStats,
      historyRecords:
          history.isLoading || history.hasError ? [] : history.requireValue,
      isHistoryLoading: history.isLoading,
      hasHistoryError: history.hasError,
      onRetryHistory: () => ref.invalidate(statsHistoryProvider(year)),
      heatmapYear: year,
      onHeatmapYearChange: (year) => setState(
        () => _selectedHeatmapYear = year == currentYear ? null : year,
      ),
    ));
  }

  AppBar _buildStatsAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = theme.brightness == Brightness.light
        ? AppColors.redesignForeground
        : theme.colorScheme.onSurface;
    final canPop = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    return AppBar(
      leadingWidth: 48,
      titleSpacing: AppSizes.xs,
      leading: canPop
          ? IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: () => Navigator.maybePop(context),
              icon: Transform.translate(
                offset: const Offset(5, 6),
                child: Icon(LucideIcons.arrowLeft, size: 20, color: foreground),
              ),
            )
          : null,
      title: Transform.translate(
        offset: const Offset(0, 6),
        child: Text(
          '학습 통계',
          style: TextStyle(
            fontFamily: redesignFontFamily,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            height: 1.4,
            letterSpacing: -0.5,
            color: foreground,
          ),
        ),
      ),
    );
  }
}
