import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/current_account_provider.dart';
import '../../../../core/providers/study_clock_provider.dart';
import '../../../../shared/widgets/app_error_retry.dart';
import '../../../home/data/models/category_goals_model.dart';
import '../../../home/providers/home_provider.dart';
import '../../../my/providers/settings_sync_provider.dart';
import '../../providers/study_provider.dart';
import '../quiz_launch.dart';
import 'today_study_distribution_breakdown.dart';
import 'today_study_goal_picker.dart';
import 'today_study_progress_summary.dart';
import 'today_study_sheet_handle.dart';
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
    final theme = Theme.of(context);
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
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: livePreview.isLoading && _accountCurrent
              ? const CircularProgressIndicator(semanticsLabel: '오늘의 학습 확인 중')
              : AppErrorRetry(onRetry: () {
                  if (!_accountCurrent) {
                    Navigator.pop(context);
                    return;
                  }
                  ref.invalidate(previewProvider);
                }),
        ),
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TodayStudySheetHandle(),
            const SizedBox(height: 20),
            Text(
              '오늘의 학습',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            TodayStudyProgressSummary(
              progress: progress,
              jlptLevel: widget.jlptLevel,
              category: widget.category,
              currentGoal: currentGoal,
              onGoalTap: canEdit && !_isGoalLoading && currentGoal != null
                  ? () => _showGoalPicker(
                        currentGoal: currentGoal,
                        category: category,
                        hasCategoryGoal: hasCategoryGoal,
                      )
                  : null,
            ),
            const SizedBox(height: 24),
            TodayStudyDistributionBreakdown(
              distribution: dist,
              category: widget.category,
            ),
            const SizedBox(height: 24),
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
        ),
      ),
    );
  }
}
