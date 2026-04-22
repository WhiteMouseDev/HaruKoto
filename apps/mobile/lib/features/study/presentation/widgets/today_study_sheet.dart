import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/user_preferences_provider.dart';
import '../../../home/providers/home_provider.dart';
import '../../../my/providers/settings_sync_provider.dart';
import '../../data/models/smart_preview_model.dart';
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
  final SmartPreviewModel data;
  final String jlptLevel;
  final String category;

  const TodayStudySheet({
    super.key,
    required this.data,
    required this.jlptLevel,
    this.category = 'VOCABULARY',
  });

  @override
  ConsumerState<TodayStudySheet> createState() => _TodayStudySheetState();
}

class _TodayStudySheetState extends ConsumerState<TodayStudySheet> {
  bool _isGoalLoading = false;

  Future<void> _updateGoal(int goal) async {
    if (_isGoalLoading) return;
    setState(() => _isGoalLoading = true);
    try {
      await ref.read(settingsSyncServiceProvider).updateDailyGoal(goal);
      ref.invalidate(dashboardProvider);
      ref.invalidate(
        smartPreviewProvider(
            (category: widget.category, jlptLevel: widget.jlptLevel)),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('하루 목표가 $goal개로 변경되었습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
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

  Future<void> _showGoalPicker() async {
    final goal = await showTodayStudyGoalPicker(
      context: context,
      currentGoal: ref.read(userPreferencesProvider).dailyGoal,
      isGoalLoading: _isGoalLoading,
    );
    if (!mounted || goal == null) return;
    await _updateGoal(goal);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = widget.data;
    final currentGoal = ref.watch(userPreferencesProvider).dailyGoal;
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
              onGoalTap: _showGoalPicker,
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
              onStart: dist.total > 0
                  ? () {
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
