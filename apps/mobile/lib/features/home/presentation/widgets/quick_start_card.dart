import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/current_account_provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/providers/study_clock_provider.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../shared/widgets/app_segmented_tabs.dart';
import '../../../../shared/widgets/app_skeleton.dart';
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
    this.isLoading = false,
    this.dailyGoal = 10,
    this.dailyGoalKnown = true,
    this.jlptLevel = 'N5',
    this.showSavedQuiz = true,
  });

  final TodayStats? today;
  final bool isLoading;
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
    final owner = ref.watch(currentAccountIdProvider);
    final canStart =
        owner != null && ref.watch(currentAccountReaderProvider)() == owner;
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final border =
        isLight ? const Color(0xFFE5E5EC) : theme.colorScheme.outline;
    final foreground =
        isLight ? const Color(0xFF111111) : theme.colorScheme.onSurface;
    final secondary =
        isLight ? const Color(0xFF666666) : theme.colorScheme.onSurfaceVariant;
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
    final savedAnswerLabel = savedQuiz.savedAnswerLabel;

    return Padding(
      padding: AppSizes.pageHorizontalEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.5),
            child: AppSegmentedTabs(
              labels: [for (final category in categories) category.label],
              tabKeys: [
                for (final category in categories)
                  ValueKey('quick-start-tab-${category.name}'),
              ],
              compact: true,
              labelFontWeight: FontWeight.w500,
              selectedIndex: _selectedIndex,
              onChanged: _selectTab,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: _DailyGoalGauge(
              category: category,
              progress: dailyProgress,
              isLoading: widget.isLoading,
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLowest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StudyDetailRow(
                  iconAsset: 'assets/icons/figma-home-goal.png',
                  label: '하루 목표',
                  labelColor: foreground,
                  value: widget.isLoading
                      ? Semantics(
                          label: '하루 목표를 불러오는 중',
                          child: const AppSkeletonBlock(width: 72, height: 14),
                        )
                      : _DailyCount(progress: dailyProgress, color: foreground),
                  goalDivider: border,
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Column(
                    children: [
                      if (reviewCount != null || preview?.isLoading == true)
                        _StudyDetailRow(
                          iconAsset: 'assets/icons/figma-home-review.png',
                          label: '복습할 문제',
                          labelColor: secondary,
                          value: reviewCount == null
                              ? Semantics(
                                  label: '복습할 문제를 불러오는 중',
                                  child: const AppSkeletonBlock(
                                      width: 48, height: 12),
                                )
                              : Text(
                                  '$reviewCount문제',
                                  style: _studyText(14,
                                      color: secondary, height: 1.5),
                                  textAlign: TextAlign.end,
                                ),
                        ),
                      _StudyDetailRow(
                        iconAsset: 'assets/icons/figma-home-difficulty.png',
                        iconWidth: 16.25,
                        label: '난이도',
                        labelColor: secondary,
                        value: Text(
                          jlptLevel,
                          style: _studyText(14, color: secondary, height: 1.5),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (savedAnswerLabel != null) ...[
            const SizedBox(height: AppSizes.sm),
            Text(
              '이번 퀴즈 $savedAnswerLabel',
              key: const ValueKey('quick-start-saved-progress'),
              textAlign: TextAlign.center,
              style: _studyText(12, color: secondary),
            ),
          ],
          const SizedBox(height: AppSizes.sm),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              textStyle: _studyText(14, weight: FontWeight.w600),
              backgroundColor: isLight ? AppColors.brandPink : null,
              foregroundColor: isLight ? Colors.white : null,
            ),
            onPressed: canStart
                ? () {
                    if (ref.read(currentAccountIdProvider) != owner ||
                        ref.read(currentAccountReaderProvider)() != owner) {
                      return;
                    }
                    HapticService().light();
                    executeStudyEntryDecision(
                      context,
                      decision: entry,
                      category: quizType,
                      jlptLevel: jlptLevel,
                      incomplete: savedQuiz.session,
                      canShowPreview: canShowPreview,
                    );
                  }
                : null,
            child: Text(ctaLabel, textAlign: TextAlign.center),
          ),
          Center(
            child: TextButton.icon(
              onPressed: () {
                HapticService().selection();
                context.push('/study/wrong-answers');
              },
              style: TextButton.styleFrom(
                foregroundColor: foreground,
                minimumSize: const Size(48, 48),
                iconAlignment: IconAlignment.end,
                textStyle: _studyText(13, weight: FontWeight.w500),
              ),
              label: const Text('오답노트 확인하기'),
              icon: SizedBox.square(
                dimension: 16,
                child: Center(
                  child: Image.asset(
                    'assets/icons/figma-home-arrow.png',
                    width: 6.25,
                    height: 11,
                    color: isLight ? null : foreground,
                    excludeFromSemantics: true,
                  ),
                ),
              ),
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
    required this.iconAsset,
    required this.label,
    required this.labelColor,
    required this.value,
    this.iconWidth = 20,
    this.goalDivider,
    this.onEdit,
    this.editLabel,
  });

  final String iconAsset;
  final double iconWidth;
  final String label;
  final Color labelColor;
  final Widget value;
  final Color? goalDivider;
  final VoidCallback? onEdit;
  final String? editLabel;

  @override
  Widget build(BuildContext context) {
    final divider = goalDivider;
    final isGoal = divider != null;
    final row = Container(
      constraints: BoxConstraints(minHeight: isGoal ? 43 : 28),
      padding: EdgeInsets.fromLTRB(
        13,
        isGoal ? 7 : 3.5,
        13,
        isGoal ? 1 : 3.5,
      ),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 20,
            child: Center(
              child: Image.asset(
                iconAsset,
                width: iconWidth,
                excludeFromSemantics: true,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.xs),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSizes.xs,
              children: [
                Text(
                  label,
                  style: _studyText(
                    isGoal ? 16 : 14,
                    color: labelColor,
                    weight: isGoal ? FontWeight.w600 : FontWeight.w400,
                    height: isGoal ? 1.4 : 1.5,
                  ),
                ),
                if (onEdit != null)
                  Image.asset(
                    'assets/icons/figma-home-edit.png',
                    width: 16,
                    excludeFromSemantics: true,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Flexible(
            child:
                Align(alignment: AlignmentDirectional.centerEnd, child: value),
          ),
        ],
      ),
    );
    if (divider == null) return row;
    final goalRegion = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        Divider(
          height: 1,
          thickness: 1,
          indent: 13,
          endIndent: 13,
          color: divider,
        ),
        // Keep the divider and its adjacent space inside the 48dp edit target.
        const SizedBox(height: 4),
      ],
    );
    if (onEdit == null) return goalRegion;
    return Tooltip(
      message: editLabel ?? label,
      child: InkWell(
        key: const ValueKey('quick-start-edit-goal'),
        onTap: onEdit,
        child: goalRegion,
      ),
    );
  }
}

class _DailyCount extends StatelessWidget {
  const _DailyCount({required this.progress, required this.color});

  final DailyGoalProgress progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const key = ValueKey('quick-start-daily-count');
    final accent = Theme.of(context).brightness == Brightness.light
        ? const Color(0xFFF06292)
        : AppColors.brandPink;
    final answeredCount = progress.answeredCount;
    if (progress.fraction == null || answeredCount == null) {
      return Text(
        progress.countLabel,
        key: key,
        textAlign: TextAlign.end,
        style: _studyText(15, color: color, height: 1.5),
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$answeredCount',
            style: _studyText(16, color: accent, weight: FontWeight.w600),
          ),
          TextSpan(text: ' / ${progress.goal}개'),
        ],
      ),
      key: key,
      textAlign: TextAlign.end,
      semanticsLabel: progress.countLabel,
      style: _studyText(15, color: color, height: 1.5),
    );
  }
}

class _DailyGoalGauge extends StatelessWidget {
  const _DailyGoalGauge({
    required this.category,
    required this.progress,
    required this.isLoading,
  });

  final DailyGoalCategory category;
  final DailyGoalProgress progress;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final foreground =
        isLight ? const Color(0xFF111111) : theme.colorScheme.onSurface;

    return Semantics(
      label: '${category.label} 하루 목표 진행률',
      value: isLoading ? '불러오는 중' : progress.percentage ?? '확인 필요',
      hint: isLoading ? null : progress.remainingLabel,
      excludeSemantics: true,
      child: SizedBox(
        width: 192,
        child: AspectRatio(
          aspectRatio: 192 / 101,
          child: CustomPaint(
            painter: _GoalArcPainter(
              progress: isLoading ? 0 : progress.fraction ?? 0,
              trackColor: isLight
                  ? const Color(0xFFF1F1F5)
                  : theme.colorScheme.surfaceContainerHighest,
              progressColor: const Color(0xFFF59BA7),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 29, 32, 9),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      category.label,
                      style: _studyText(
                        12,
                        height: 1.5,
                        weight: FontWeight.w500,
                        color: isLight
                            ? const Color(0xFFF06292)
                            : AppColors.brandPink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (isLoading)
                      const SizedBox(
                        height: 33.6,
                        child: Center(
                          child: AppSkeletonBlock(width: 55, height: 18),
                        ),
                      )
                    else
                      Text(
                        progress.percentage ?? '—',
                        key: progress.percentage == null
                            ? null
                            : const ValueKey('quick-start-percentage'),
                        style: _studyText(24,
                            color: foreground, weight: FontWeight.w600),
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
    const strokeWidth = 10.0;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height - strokeWidth / 2),
      radius:
          math.min(size.width / 2 - strokeWidth / 2, size.height - strokeWidth),
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

TextStyle _studyText(
  double size, {
  Color? color,
  FontWeight weight = FontWeight.w400,
  double height = 1.4,
}) =>
    TextStyle(
      fontFamily: 'Pretendard',
      fontSize: size,
      height: height,
      letterSpacing: -size * 0.025,
      fontWeight: weight,
      color: color,
    );
