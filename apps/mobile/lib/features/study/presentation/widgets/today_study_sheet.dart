import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/auth/current_account_provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/providers/study_clock_provider.dart';
import '../../../../core/theme/text_theme.dart';
import '../../../../shared/widgets/app_error_retry.dart';
import '../../../../shared/widgets/app_sheet_handle.dart';
import '../../../home/data/models/category_goals_model.dart';
import '../../../home/providers/home_provider.dart';
import '../../../my/providers/settings_sync_provider.dart';
import '../../providers/study_provider.dart';
import '../quiz_launch.dart';
import 'today_study_distribution_breakdown.dart';
import 'today_study_goal_picker.dart';
import 'today_study_progress_summary.dart';
import 'today_study_start_button.dart';

/// Bottom sheet for "오늘의 학습" — shows smart quiz preview,
/// distribution breakdown, goal setting, and start button.
class TodayStudySheet extends ConsumerStatefulWidget {
  final String jlptLevel;
  final String category;

  const TodayStudySheet({
    super.key,
    required this.jlptLevel,
    this.category = 'VOCABULARY',
  });

  @override
  ConsumerState<TodayStudySheet> createState() => _TodayStudySheetState();
}

class _TodayStudySheetState extends ConsumerState<TodayStudySheet> {
  bool _isGoalLoading = false;
  late final String? _owner;

  @override
  void initState() {
    super.initState();
    _owner = ref.read(currentAccountIdProvider);
  }

  bool get _accountCurrent =>
      _owner != null &&
      ref.read(currentAccountIdProvider) == _owner &&
      ref.read(currentAccountReaderProvider)() == _owner;

  Future<void> _showGoalPicker({
    required int currentGoal,
    required DailyGoalCategory category,
    required bool hasCategoryGoal,
  }) async {
    if (_isGoalLoading || !_accountCurrent) return;
    final goal = await showTodayStudyGoalPicker(
      context: context,
      currentGoal: currentGoal,
      title: hasCategoryGoal ? '${category.label} 하루 목표 설정' : '하루 목표 설정',
    );
    if (!mounted || goal == null || goal == currentGoal || !_accountCurrent) {
      return;
    }

    setState(() => _isGoalLoading = true);
    try {
      final settings = ref.read(settingsSyncServiceProvider);
      if (hasCategoryGoal) {
        await settings.updateCategoryDailyGoal(category, goal);
      } else {
        await settings.updateDailyGoal(goal);
      }
      if (mounted && _accountCurrent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('하루 목표가 $goal개로 변경되었습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted && _accountCurrent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('목표 변경에 실패했습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGoalLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category == 'GRAMMAR'
        ? DailyGoalCategory.grammar
        : DailyGoalCategory.vocabulary;
    final previewProvider = smartPreviewProvider(
        (category: widget.category, jlptLevel: widget.jlptLevel));
    final livePreview = ref.watch(previewProvider);
    ref.watch(currentAccountIdProvider);
    if (!_accountCurrent ||
        livePreview.isLoading ||
        livePreview.hasError ||
        !livePreview.hasValue) {
      return _TodayStudySheetLayout(
        title: '오늘의 ${category.label}',
        children: [
          if (livePreview.isLoading && _accountCurrent)
            const Center(
              child: CircularProgressIndicator(semanticsLabel: '오늘의 학습 확인 중'),
            )
          else
            AppErrorRetry(onRetry: () {
              if (!_accountCurrent) {
                Navigator.pop(context);
                return;
              }
              ref.invalidate(previewProvider);
            }),
        ],
      );
    }
    final data = livePreview.value!;
    final dashboard = ref.watch(dashboardProvider);
    final date = studyDateKey(ref.watch(studyDateProvider));
    final categoryGoals = dashboard.value?.today.categoryGoals;
    final hasCategoryGoal = categoryGoals?.date == date;
    final canEdit = !dashboard.isLoading &&
        !dashboard.hasError &&
        (hasCategoryGoal ||
            (dashboard.hasValue &&
                categoryGoals == null &&
                category == DailyGoalCategory.vocabulary));
    final currentGoal =
        hasCategoryGoal || category == DailyGoalCategory.vocabulary
            ? data.dailyGoal
            : null;
    final dist = data.sessionDistribution;
    final progress = data.overallProgress;

    return _TodayStudySheetLayout(
      title: '오늘의 ${category.label}',
      children: [
        _TodayStudyGoal(
          jlptLevel: widget.jlptLevel,
          currentGoal: currentGoal,
          onGoalTap: canEdit && !_isGoalLoading && currentGoal != null
              ? () => _showGoalPicker(
                    currentGoal: currentGoal,
                    category: category,
                    hasCategoryGoal: hasCategoryGoal,
                  )
              : null,
        ),
        const SizedBox(height: AppSizes.md),
        TodayStudyDistributionBreakdown(
          distribution: dist,
          category: widget.category,
        ),
        if (progress.total > 0) ...[
          const SizedBox(height: AppSizes.md),
          TodayStudyProgressSummary(
            progress: progress,
            jlptLevel: widget.jlptLevel,
            category: widget.category,
          ),
        ],
        const SizedBox(height: AppSizes.md),
        TodayStudyStartButton(
          totalCount: dist.total,
          category: widget.category,
          onStart: dist.total > 0 && !_isGoalLoading
              ? () {
                  if (!_accountCurrent) return;
                  Navigator.pop(context);
                  openQuizPageForSession(
                    context,
                    quizType: widget.category,
                    jlptLevel: widget.jlptLevel,
                    count: dist.total,
                    mode: 'smart',
                  );
                }
              : null,
        ),
      ],
    );
  }
}

class _TodayStudySheetLayout extends StatelessWidget {
  const _TodayStudySheetLayout({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSizes.pageHorizontal,
        AppSizes.pageHorizontal,
        AppSizes.pageHorizontal,
        math.max(AppSizes.lg, MediaQuery.paddingOf(context).bottom),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSheetHandle(),
          const SizedBox(height: AppSizes.md),
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontFamily: redesignFontFamily,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                height: 1.4,
                color: theme.brightness == Brightness.light
                    ? AppColors.redesignForeground
                    : null,
              ),
            ),
          ),
          const SizedBox(height: AppSizes.xs),
          ...children,
        ],
      ),
    );
  }
}

class _TodayStudyGoal extends StatelessWidget {
  const _TodayStudyGoal({
    required this.jlptLevel,
    required this.currentGoal,
    required this.onGoalTap,
  });

  final String jlptLevel;
  final int? currentGoal;
  final VoidCallback? onGoalTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      fontFamily: redesignFontFamily,
      color: theme.brightness == Brightness.light
          ? AppColors.redesignMutedForeground
          : theme.colorScheme.onSurfaceVariant,
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSizes.xs,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.sm, vertical: AppSizes.xs),
            child: Text(
              jlptLevel,
              style: labelStyle?.copyWith(
                color: AppColors.sakuraOn,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        if (currentGoal case final goal?)
          if (onGoalTap != null)
            TextButton(
              onPressed: onGoalTap,
              style: TextButton.styleFrom(
                foregroundColor: labelStyle?.color,
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.xs),
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSizes.xs,
                children: [
                  Text('하루 목표 $goal개',
                      textAlign: TextAlign.center, style: labelStyle),
                  const Icon(LucideIcons.pencil, size: 12),
                ],
              ),
            )
          else
            Text(
              '하루 목표 $goal개',
              style: labelStyle,
            ),
      ],
    );
  }
}
