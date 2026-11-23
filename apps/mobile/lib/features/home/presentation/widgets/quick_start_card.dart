import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/auth/current_account_provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/providers/study_clock_provider.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_segmented_tabs.dart';
import '../../../my/providers/settings_sync_provider.dart';
import '../../../study/presentation/study_entry_flow.dart';
import '../../../study/presentation/widgets/today_study_goal_picker.dart';
import '../../../study/providers/study_provider.dart';
import '../../data/models/category_goals_model.dart';
import '../../data/models/dashboard_model.dart';
import '../../domain/daily_goal_progress.dart';
import '../../domain/quick_start_progress.dart';

class QuickStartCard extends ConsumerStatefulWidget {
  const QuickStartCard({
    super.key,
    this.today,
    this.dailyGoal = 10,
    this.dailyGoalKnown = true,
    this.jlptLevel = 'N5',
    this.showSavedQuiz = true,
  });

  final TodayStats? today;
  final int dailyGoal;
  final bool dailyGoalKnown;
  final String jlptLevel;
  final bool showSavedQuiz;

  @override
  ConsumerState<QuickStartCard> createState() => _QuickStartCardState();
}

class _QuickStartCardState extends ConsumerState<QuickStartCard> {
  int _selectedIndex = 0;

  void _selectTab(int index) {
    if (index == _selectedIndex) return;
    HapticService().selection();
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const categories = DailyGoalCategory.values;
    final category = categories[_selectedIndex];
    final quizType = category == DailyGoalCategory.sentence
        ? 'SENTENCE_ARRANGE'
        : category.apiValue;
    final jlptLevel = widget.jlptLevel;
    final today = widget.today;
    final studyDate = ref.watch(studyDateProvider);
    final categoryGoals = today?.categoryGoals;
    final hasCategoryGoals = categoryGoals?.date == studyDateKey(studyDate);
    final dailyProgress = resolveDailyGoalProgress(
      category: category,
      categoryGoals: categoryGoals,
      vocabularyGoal: today?.vocabularyGoal,
      dailyGoal: widget.dailyGoalKnown ? widget.dailyGoal : 0,
      studyDate: studyDate,
    );
    final canEditGoal = hasCategoryGoals ||
        (today != null &&
            categoryGoals == null &&
            category == DailyGoalCategory.vocabulary &&
            widget.dailyGoalKnown);

    final incompleteAsync =
        widget.showSavedQuiz ? ref.watch(incompleteQuizProvider) : null;
    final savedQuiz = resolveQuickStartProgress(
      category: quizType,
      jlptLevel: jlptLevel,
      sessionLoading: incompleteAsync?.isLoading ?? false,
      sessionError: incompleteAsync?.hasError ?? false,
      incomplete: incompleteAsync?.value,
    );
    final preview = categorySupportsSmartStudy(quizType)
        ? ref.watch(smartPreviewProvider(
            (category: quizType, jlptLevel: jlptLevel),
          ))
        : null;
    final canShowPreview = preview != null &&
        (preview.isLoading || (preview.hasValue && !preview.hasError));
    final reviewCount =
        preview != null && !preview.isLoading && !preview.hasError
            ? preview.value?.sessionDistribution.review
            : null;
    final entry = resolveStudyEntryDecision(
      category: quizType,
      hasIncomplete: savedQuiz.session != null,
      canShowPreview: canShowPreview,
    );
    final ctaLabel = entry.action == StudyEntryActionKind.resumeOrNew
        ? '이어서 학습하기'
        : '오늘의 ${category.label} 학습하기';
    final remaining = dailyProgress.remainingLabel;
    final savedAnswerLabel = savedQuiz.savedAnswerLabel;

    return Padding(
      padding: AppSizes.pageHorizontalEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSegmentedTabs(
            labels: [for (final category in categories) category.label],
            tabKeys: [
              for (final category in categories)
                ValueKey('quick-start-tab-${category.name}'),
            ],
            selectedIndex: _selectedIndex,
            onChanged: _selectTab,
          ),
          const SizedBox(height: AppSizes.md),
          Center(
            child: _DailyGoalGauge(
              category: category,
              progress: dailyProgress,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StudyDetailRow(
                  icon: LucideIcons.flag,
                  label: '하루 목표',
                  value: dailyProgress.countLabel,
                  valueKey: const ValueKey('quick-start-daily-count'),
                  onEdit: canEditGoal
                      ? () => _showDailyGoalSheet(
                            context,
                            category: category,
                            currentGoal: dailyProgress.goal,
                            hasCategoryGoal: hasCategoryGoals,
                          )
                      : null,
                  editLabel: '${category.label} 하루 목표 설정',
                ),
                if (reviewCount != null) ...[
                  const Divider(height: 1),
                  _StudyDetailRow(
                    icon: LucideIcons.repeat,
                    label: '복습할 문제',
                    value: '$reviewCount문제',
                  ),
                ],
                const Divider(height: 1),
                _StudyDetailRow(
                  icon: LucideIcons.barChart3,
                  label: '난이도',
                  value: jlptLevel,
                ),
              ],
            ),
          ),
          if (remaining != null || savedAnswerLabel != null) ...[
            const SizedBox(height: AppSizes.sm),
            if (remaining != null)
              Text(
                remaining,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (savedAnswerLabel != null)
              Text(
                '이번 퀴즈 $savedAnswerLabel',
                key: const ValueKey('quick-start-saved-progress'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
          const SizedBox(height: AppSizes.sm),
          FilledButton(
            onPressed: () {
              HapticService().light();
              executeStudyEntryDecision(
                context,
                decision: entry,
                category: quizType,
                jlptLevel: jlptLevel,
                incomplete: savedQuiz.session,
                canShowPreview: canShowPreview,
              );
            },
            child: Text(ctaLabel, textAlign: TextAlign.center),
          ),
          Center(
            child: TextButton.icon(
              onPressed: () {
                HapticService().selection();
                context.push('/study/wrong-answers');
              },
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurface,
                minimumSize: const Size(48, 48),
                iconAlignment: IconAlignment.end,
              ),
              label: const Text('오답노트 확인하기'),
              icon: const Icon(LucideIcons.chevronRight, size: 16),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDailyGoalSheet(
    BuildContext context, {
    required DailyGoalCategory category,
    required int currentGoal,
    required bool hasCategoryGoal,
  }) async {
    final owner = ref.read(currentAccountIdProvider);
    if (owner == null || ref.read(currentAccountReaderProvider)() != owner) {
      return;
    }
    final selectedGoal = await showTodayStudyGoalPicker(
      context: context,
      currentGoal: currentGoal,
      title: hasCategoryGoal ? '${category.label} 하루 목표 설정' : '하루 목표 설정',
    );

    bool accountCurrent() =>
        ref.read(currentAccountIdProvider) == owner &&
        ref.read(currentAccountReaderProvider)() == owner;
    if (!context.mounted ||
        selectedGoal == null ||
        selectedGoal == currentGoal ||
        !accountCurrent()) {
      return;
    }

    try {
      final settings = ref.read(settingsSyncServiceProvider);
      if (hasCategoryGoal) {
        await settings.updateCategoryDailyGoal(category, selectedGoal);
      } else {
        await settings.updateDailyGoal(selectedGoal);
      }

      if (context.mounted && accountCurrent()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('하루 목표가 $selectedGoal개로 변경되었습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (context.mounted && accountCurrent()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('목표 변경에 실패했습니다. 다시 시도해주세요.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

class _StudyDetailRow extends StatelessWidget {
  const _StudyDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueKey,
    this.onEdit,
    this.editLabel,
  });

  final IconData icon;
  final String label;
  final String value;
  final Key? valueKey;
  final VoidCallback? onEdit;
  final String? editLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final row = Container(
      constraints: BoxConstraints(minHeight: onEdit == null ? 36 : 48),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.gap,
        vertical: AppSizes.xs,
      ),
      child: Row(
        children: [
          Icon(icon, size: AppSizes.iconSm, color: muted),
          const SizedBox(width: AppSizes.sm),
          Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
          const SizedBox(width: AppSizes.sm),
          Flexible(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                value,
                key: valueKey,
                textAlign: TextAlign.end,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (onEdit != null) ...[
            const SizedBox(width: AppSizes.xs),
            Icon(LucideIcons.pencil, size: 14, color: muted),
          ],
        ],
      ),
    );
    if (onEdit == null) return row;
    return Tooltip(
      message: editLabel ?? label,
      child: InkWell(
        key: const ValueKey('quick-start-edit-goal'),
        onTap: onEdit,
        child: row,
      ),
    );
  }
}

class _DailyGoalGauge extends StatelessWidget {
  const _DailyGoalGauge({required this.category, required this.progress});

  final DailyGoalCategory category;
  final DailyGoalProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.brightness == Brightness.light
        ? AppColors.primaryButton
        : AppColors.sakura;

    return Semantics(
      label: '${category.label} 하루 목표 진행률',
      value: progress.percentage ?? '확인 필요',
      excludeSemantics: true,
      child: SizedBox(
        width: 192,
        child: AspectRatio(
          aspectRatio: 2,
          child: CustomPaint(
            painter: _GoalArcPainter(
              progress: progress.fraction ?? 0,
              trackColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              progressColor: AppColors.sakura,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      category.label,
                      style:
                          theme.textTheme.labelMedium?.copyWith(color: accent),
                    ),
                    Text(
                      progress.percentage ?? '—',
                      key: progress.percentage == null
                          ? null
                          : const ValueKey('quick-start-percentage'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalArcPainter extends CustomPainter {
  const _GoalArcPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 8.0;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height - strokeWidth / 2),
      radius: size.height - strokeWidth,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = trackColor;
    canvas.drawArc(rect, math.pi, math.pi, false, paint);
    if (progress > 0) {
      canvas.drawArc(
        rect,
        math.pi,
        math.pi * progress,
        false,
        paint..color = progressColor,
      );
    }
  }

  @override
  bool shouldRepaint(_GoalArcPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      trackColor != oldDelegate.trackColor ||
      progressColor != oldDelegate.progressColor;
}
