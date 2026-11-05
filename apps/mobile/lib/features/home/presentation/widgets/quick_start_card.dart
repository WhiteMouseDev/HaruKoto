import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/auth/current_account_provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/providers/study_clock_provider.dart';
import '../../../my/providers/settings_sync_provider.dart';
import '../../../study/providers/study_provider.dart';
import '../../../study/presentation/study_entry_flow.dart';
import '../../../study/presentation/widgets/today_study_goal_picker.dart';
import '../../data/models/category_goals_model.dart';
import '../../data/models/dashboard_model.dart';
import '../../domain/quick_start_progress.dart';
import '../../domain/daily_goal_progress.dart';

// ═══════════════════════════════════════════════════════════════
//  Constants
// ═══════════════════════════════════════════════════════════════
const _tabWidth = 52.0;
const _tabHeight = 72.0;

const _tabBgColors = [
  AppColors.primary,
  AppColors.grammar,
  AppColors.kanji,
];

const _categories = [
  _CategoryInfo(
    icon: LucideIcons.bookOpen,
    goalCategory: DailyGoalCategory.vocabulary,
    ctaLabel: '오늘의 단어',
    title: '단어 학습',
    color: AppColors.primary,
    containerColor: AppColors.primaryContainer,
  ),
  _CategoryInfo(
    icon: LucideIcons.braces,
    goalCategory: DailyGoalCategory.grammar,
    ctaLabel: '오늘의 문법',
    title: '문법 학습',
    color: AppColors.grammar,
    containerColor: AppColors.grammarContainer,
  ),
  _CategoryInfo(
    icon: LucideIcons.alignLeft,
    goalCategory: DailyGoalCategory.sentence,
    ctaLabel: '오늘의 문장배열',
    title: '문장배열 학습',
    color: AppColors.kanji,
    containerColor: AppColors.kanjiContainer,
  ),
];

// ═══════════════════════════════════════════════════════════════
//  QuickStartCard
// ═══════════════════════════════════════════════════════════════
class QuickStartCard extends ConsumerStatefulWidget {
  final LevelProgressData? levelProgress;
  final TodayStats? today;
  final int dailyGoal;
  final bool dailyGoalKnown;
  final String jlptLevel;
  final bool showSavedQuiz;

  const QuickStartCard({
    super.key,
    this.levelProgress,
    this.today,
    this.dailyGoal = 10,
    this.dailyGoalKnown = true,
    this.jlptLevel = 'N5',
    this.showSavedQuiz = true,
  });

  @override
  ConsumerState<QuickStartCard> createState() => _QuickStartCardState();
}

class _QuickStartCardState extends ConsumerState<QuickStartCard>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late final AnimationController _animController;
  late Animation<double> _animatedIndex;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _animatedIndex = AlwaysStoppedAnimation(_selectedIndex.toDouble());
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == _selectedIndex) return;
    HapticService().selection();
    final oldIndex = _selectedIndex;
    setState(() => _selectedIndex = index);

    _animatedIndex = Tween<double>(
      begin: oldIndex.toDouble(),
      end: index.toDouble(),
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOutCubic,
    ));
    _animController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardBg = theme.colorScheme.surfaceContainerLowest;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.pageHorizontal),
      child: IntrinsicHeight(
        child: Stack(
          children: [
            // ── Layer 1: Gooey tab rail (all tabs as one organic shape) ──
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: GooeyTabRailPainter(
                      animatedIndex: _animatedIndex.value,
                      tabCount: _categories.length,
                      tabHeight: _tabHeight,
                      tabWidth: _tabWidth,
                      tabColors: _tabBgColors,
                      cardColor: cardBg,
                      cardRadius: AppSizes.cardRadius.toDouble(),
                    ),
                  );
                },
              ),
            ),

            // ── Layer 2: Main content ──
            Padding(
              padding: const EdgeInsets.only(right: _tabWidth),
              child: _MainContent(
                selectedIndex: _selectedIndex,
                levelProgress: widget.levelProgress,
                today: widget.today,
                dailyGoal: widget.dailyGoal,
                dailyGoalKnown: widget.dailyGoalKnown,
                jlptLevel: widget.jlptLevel,
                showSavedQuiz: widget.showSavedQuiz,
              ),
            ),

            // ── Layer 3: Tab icons + hit areas ──
            Positioned(
              right: 0,
              top: 0,
              width: _tabWidth,
              child: Column(
                children: [
                  for (int i = 0; i < _categories.length; i++)
                    GestureDetector(
                      key: ValueKey(
                          'quick-start-tab-${_categories[i].goalCategory.name}'),
                      onTap: () => _selectTab(i),
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox(
                        width: _tabWidth,
                        height: _tabHeight,
                        child: Center(
                          child: Icon(
                            _categories[i].icon,
                            size: 24,
                            color: i == _selectedIndex
                                ? _tabBgColors[i]
                                : Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
//  GooeyCardPainter — draws the white card that EXTENDS outward
//  to cover the active tab. Inactive tabs remain visible behind.
//
//  The right edge normally sits at `cardRight`. At the active tab,
//  the edge bumps out to `w` (full width), covering the tab.
//  Smooth cubic bezier S-curves create the gooey transition.
// ═══════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════
//  GooeyTabRailPainter — draws the ENTIRE card + tab rail as
//  one unified organic shape.
//
//  1. Draws the white card (left area)
//  2. The active tab merges seamlessly with the card
//  3. Each non-active tab is drawn with its own color
//  4. Concave bezier curves connect adjacent tabs on the left edge
//  5. Right edges are uniformly rounded (radius ~28)
// ═══════════════════════════════════════════════════════════════
class GooeyTabRailPainter extends CustomPainter {
  final double animatedIndex;
  final int tabCount;
  final double tabHeight;
  final double tabWidth;
  final List<Color> tabColors;
  final Color cardColor;
  final double cardRadius;

  GooeyTabRailPainter({
    required this.animatedIndex,
    required this.tabCount,
    required this.tabHeight,
    required this.tabWidth,
    required this.tabColors,
    required this.cardColor,
    required this.cardRadius,
  });

  // Gemini-calculated bezier constants
  static const _gooeyR = 24.0; // concave curve size (matches cardRadius)
  static const _tabR = 24.0; // tab right-side rounding

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final baseX = w - tabWidth; // card's right edge
    final activeIdx = animatedIndex.round();

    // ── Step 1: Draw non-active tabs (bottom-up so upper tabs overlap lower) ──
    for (int i = tabCount - 1; i >= 0; i--) {
      if (i == activeIdx) continue;
      final top = i * tabHeight;
      final bottom = top + tabHeight;
      final tabTop = i == 0 ? top : top - 4;
      final tabBottom = i == tabCount - 1 ? bottom : bottom + 4;
      final rrect = RRect.fromLTRBAndCorners(
        baseX,
        tabTop,
        w,
        tabBottom,
        topRight: const Radius.circular(_tabR),
        bottomRight: const Radius.circular(_tabR),
      );
      canvas.drawRRect(rrect, Paint()..color = tabColors[i % tabColors.length]);
    }

    // ── Step 2: Draw white card + active tab (Gemini bezier formula) ──
    const g = _gooeyR;
    final r = cardRadius;
    final h = size.height;

    // Active tab Y (animated for smooth transition)
    final tabTop = animatedIndex * tabHeight;
    final tabBottom = tabTop + tabHeight;

    final path = Path();

    // 1. Top-left corner
    path.moveTo(r, 0);

    // 2. Top edge
    if (animatedIndex < 0.5) {
      // First tab active: card top extends full width with rounded top-right
      path.lineTo(w - r, 0);
      path.quadraticBezierTo(w, 0, w, r);
    } else {
      // Top edge to baseX, then down
      path.lineTo(baseX, 0);
      path.lineTo(baseX, tabTop - g);

      // 3. UPPER GOOEY CONCAVE (Gemini cubicTo formula)
      path.cubicTo(
        baseX, tabTop - g * 0.5, // cp1
        baseX + g * 0.5, tabTop, // cp2
        baseX + g, tabTop, // end
      );

      // 4. Active tab top edge + rounded top-right
      path.lineTo(w - r, tabTop);
      path.quadraticBezierTo(w, tabTop, w, tabTop + r);
    }

    // 5. Active tab right edge
    path.lineTo(w, tabBottom - r);

    // 6. Active tab bottom-right + bottom edge
    path.quadraticBezierTo(w, tabBottom, w - r, tabBottom);
    path.lineTo(baseX + g, tabBottom);

    // 7. LOWER GOOEY CONCAVE (Gemini cubicTo formula)
    path.cubicTo(
      baseX + g * 0.5, tabBottom, // cp1
      baseX, tabBottom + g * 0.5, // cp2
      baseX, tabBottom + g, // end
    );

    // 8. Continue down to bottom-right
    path.lineTo(baseX, h - r);
    path.quadraticBezierTo(baseX, h, baseX - r, h);

    // 9. Bottom + left edges
    path.lineTo(r, h);
    path.quadraticBezierTo(0, h, 0, h - r);
    path.lineTo(0, r);
    path.quadraticBezierTo(0, 0, r, 0);

    path.close();

    // Shadow + fill
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.06), 12, false);
    canvas.drawPath(path, Paint()..color = cardColor);
  }

  @override
  bool shouldRepaint(GooeyTabRailPainter old) =>
      old.animatedIndex != animatedIndex || old.cardColor != cardColor;
}

// ═══════════════════════════════════════════════════════════════
//  _MainContent — the card's inner content (icon, title, CTA…)
// ═══════════════════════════════════════════════════════════════
class _MainContent extends ConsumerWidget {
  final int selectedIndex;
  final LevelProgressData? levelProgress;
  final TodayStats? today;
  final int dailyGoal;
  final bool dailyGoalKnown;
  final String jlptLevel;
  final bool showSavedQuiz;

  const _MainContent({
    required this.selectedIndex,
    this.levelProgress,
    this.today,
    required this.dailyGoal,
    required this.dailyGoalKnown,
    required this.jlptLevel,
    required this.showSavedQuiz,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mutedForeground = theme.colorScheme.onSurface.withValues(alpha: 0.65);
    final cat = _categories[selectedIndex];
    final goalCategory = cat.goalCategory;
    final apiType = goalCategory == DailyGoalCategory.sentence
        ? 'SENTENCE_ARRANGE'
        : goalCategory.apiValue;
    final progress = switch (goalCategory) {
      DailyGoalCategory.vocabulary => levelProgress?.vocabulary,
      DailyGoalCategory.grammar => levelProgress?.grammar,
      DailyGoalCategory.sentence => null,
    };
    final hasProgress = progress != null && progress.total > 0;
    final incompleteAsync =
        showSavedQuiz ? ref.watch(incompleteQuizProvider) : null;
    final previewAsync = switch (apiType) {
      'VOCABULARY' => ref.watch(
          smartPreviewProvider((category: 'VOCABULARY', jlptLevel: jlptLevel)),
        ),
      'GRAMMAR' => ref.watch(
          smartPreviewProvider((category: 'GRAMMAR', jlptLevel: jlptLevel)),
        ),
      _ => null,
    };
    final cardProgress = resolveQuickStartProgress(
      category: apiType,
      jlptLevel: jlptLevel,
      sessionLoading: incompleteAsync?.isLoading ?? false,
      sessionError: incompleteAsync?.hasError ?? false,
      incomplete:
          incompleteAsync?.hasValue == true ? incompleteAsync!.value : null,
      mastery: progress,
    );
    final studyDate = ref.watch(studyDateProvider);
    final categoryGoals = today?.categoryGoals;
    final hasCategoryGoal = categoryGoals?.date == studyDateKey(studyDate);
    final dailyProgress = resolveDailyGoalProgress(
      category: goalCategory,
      categoryGoals: categoryGoals,
      vocabularyGoal: today?.vocabularyGoal,
      dailyGoal: dailyGoalKnown ? dailyGoal : 0,
      studyDate: studyDate,
    );
    final canEditGoal = hasCategoryGoal ||
        (today != null &&
            categoryGoals == null &&
            goalCategory == DailyGoalCategory.vocabulary &&
            dailyGoalKnown);
    final incomplete = cardProgress.session;
    final canShowPreview = previewAsync != null &&
        (previewAsync.isLoading ||
            (previewAsync.hasValue && !previewAsync.hasError));
    final decision = resolveStudyEntryDecision(
      category: apiType,
      hasIncomplete: incomplete != null,
      canShowPreview: canShowPreview,
    );

    final ctaLabel = decision.action == StudyEntryActionKind.resumeOrNew
        ? '이어서 학습하기'
        : cat.ctaLabel;

    final stackDailyProgress = MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(14) > 18.2;
    final countText = Text(
      dailyProgress.countLabel,
      key: const ValueKey('quick-start-daily-count'),
      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    );
    final progressSummary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cat.title,
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        if (canEditGoal)
          Tooltip(
            message: '${goalCategory.label} 하루 목표 설정',
            child: InkWell(
              key: const ValueKey('quick-start-edit-goal'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showDailyGoalSheet(
                context,
                ref,
                category: goalCategory,
                currentGoal: dailyProgress.goal,
                hasCategoryGoal: hasCategoryGoal,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: countText),
                    const SizedBox(width: 6),
                    Icon(LucideIcons.pencil,
                        size: 14,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.4)),
                  ],
                ),
              ),
            ),
          )
        else
          countText,
        if (dailyProgress.remainingLabel != null)
          Text(
            dailyProgress.remainingLabel!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        if (cardProgress.savedAnswerLabel != null) ...[
          const SizedBox(height: 8),
          Text(
            stackDailyProgress
                ? '이번 퀴즈\n${cardProgress.savedAnswerLabel!}'
                : '이번 퀴즈 ${cardProgress.savedAnswerLabel!}',
            key: const ValueKey('quick-start-saved-progress'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
    final ringFraction = dailyProgress.fraction;
    final progressRing = SizedBox(
      width: stackDailyProgress ? 100 : 72,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ringFraction != null) ...[
            SizedBox(
              width: 64,
              height: 64,
              child: CustomPaint(
                painter: _CircularProgressPainter(
                  progress: ringFraction,
                  trackColor: theme.brightness == Brightness.dark
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.12)
                      : AppColors.surfaceMuted,
                  progressColor: cat.color,
                  strokeWidth: 5,
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        dailyProgress.percentage!,
                        key: const ValueKey('quick-start-percentage'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold, color: cat.color),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          Text(
            '오늘 목표',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Category icon ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Container(
                key: ValueKey('icon_$selectedIndex'),
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: cat.containerColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(cat.icon, size: 36, color: cat.color),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ── Review accuracy ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              HapticService().selection();
              context.push('/study/wrong-answers');
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.checkCircle,
                  size: 14,
                  color: mutedForeground,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    hasProgress
                        ? '복습 정답률 ${_getAccuracy(today)}%'
                        : '복습 정답률 -%',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: mutedForeground,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  LucideIcons.chevronRight,
                  size: 14,
                  color: mutedForeground,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // ── Title + circular progress ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: stackDailyProgress
                ? Column(
                    key: ValueKey('content_$selectedIndex'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      progressSummary,
                      const SizedBox(height: 12),
                      Center(child: progressRing),
                    ],
                  )
                : Row(
                    key: ValueKey('content_$selectedIndex'),
                    children: [
                      Expanded(child: progressSummary),
                      const SizedBox(width: 8),
                      progressRing,
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 20),

        // ── CTA button ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Material(
            color: AppColors.primaryStrong,
            borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
              onTap: () {
                HapticService().light();
                executeStudyEntryDecision(
                  context,
                  decision: decision,
                  category: apiType,
                  jlptLevel: jlptLevel,
                  incomplete: incomplete,
                  canShowPreview: canShowPreview,
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      LucideIcons.bookOpen,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        ctaLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static String _getAccuracy(TodayStats? today) {
    if (today == null || today.totalAnswers == 0) return '-';
    return ((today.correctAnswers / today.totalAnswers) * 100)
        .toStringAsFixed(0);
  }

  Future<void> _showDailyGoalSheet(
    BuildContext context,
    WidgetRef ref, {
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

// ═══════════════════════════════════════════════════════════════
//  Supporting widgets
// ═══════════════════════════════════════════════════════════════

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _CircularProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CircularProgressPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.progressColor != progressColor;
}

class _CategoryInfo {
  final IconData icon;
  final DailyGoalCategory goalCategory;
  final String ctaLabel;
  final String title;
  final Color color;
  final Color containerColor;

  const _CategoryInfo({
    required this.icon,
    required this.goalCategory,
    required this.ctaLabel,
    required this.title,
    required this.color,
    required this.containerColor,
  });
}
