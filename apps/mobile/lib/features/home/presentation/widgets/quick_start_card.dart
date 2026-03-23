import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../shared/widgets/app_sheet_handle.dart';
import '../../../my/providers/my_provider.dart';
import '../../../study/providers/study_provider.dart';
import '../../../study/presentation/widgets/today_study_sheet.dart';
import '../../data/models/dashboard_model.dart';
import '../../providers/home_provider.dart';

// ═══════════════════════════════════════════════════════════════
//  Constants
// ═══════════════════════════════════════════════════════════════
const _tabWidth = 52.0;
const _tabHeight = 72.0;

const _tabBgColors = [
  Color(0xFFFFD6E0), // 단어: pastel pink
  Color(0xFFD1C4E9), // 문법: pastel lavender
  Color(0xFFB2DFDB), // 문장: pastel mint
];

const _categories = [
  _CategoryInfo(
    icon: LucideIcons.bookOpen,
    quizType: 'vocabulary',
    ctaLabel: '오늘의 단어',
    title: '단어 학습',
  ),
  _CategoryInfo(
    icon: LucideIcons.braces,
    quizType: 'grammar',
    ctaLabel: '오늘의 문법',
    title: '문법 학습',
  ),
  _CategoryInfo(
    icon: LucideIcons.alignLeft,
    quizType: 'sentence',
    ctaLabel: '오늘의 문장배열',
    title: '문장배열 학습',
  ),
];

// ═══════════════════════════════════════════════════════════════
//  QuickStartCard
// ═══════════════════════════════════════════════════════════════
class QuickStartCard extends ConsumerStatefulWidget {
  final LevelProgressData? levelProgress;
  final TodayStats? today;
  final int dailyGoal;
  final String jlptLevel;

  const QuickStartCard({
    super.key,
    this.levelProgress,
    this.today,
    this.dailyGoal = 10,
    this.jlptLevel = 'N5',
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
                jlptLevel: widget.jlptLevel,
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
      final rrect = RRect.fromLTRBAndCorners(
        baseX,
        top - 4,
        w,
        bottom + 4,
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
  final String jlptLevel;

  const _MainContent({
    required this.selectedIndex,
    this.levelProgress,
    this.today,
    required this.dailyGoal,
    required this.jlptLevel,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cat = _categories[selectedIndex];
    final progress = _getProgress(cat.quizType);
    final hasProgress = progress != null && progress.total > 0;
    final progressPct =
        hasProgress ? (progress.mastered / progress.total) : 0.0;

    // Pre-fetch smart preview for vocabulary tab
    if (cat.quizType == 'vocabulary') {
      ref.watch(
          smartPreviewProvider((category: 'VOCABULARY', jlptLevel: jlptLevel)));
    }

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
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  cat.icon,
                  size: 36,
                  color: theme.colorScheme.primary,
                ),
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
                Icon(LucideIcons.checkCircle,
                    size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  hasProgress ? '복습 정답률 ${_getAccuracy(today)}%' : '복습 정답률 -%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(LucideIcons.chevronRight,
                    size: 14, color: theme.colorScheme.primary),
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
            child: Row(
              key: ValueKey('content_$selectedIndex'),
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '하루 목표  ',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                          Text(
                            '$dailyGoal개',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _showDailyGoalSheet(context, ref),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                LucideIcons.pencil,
                                size: 14,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CustomPaint(
                    painter: _CircularProgressPainter(
                      progress: progressPct.clamp(0.0, 1.0),
                      trackColor:
                          theme.colorScheme.primary.withValues(alpha: 0.10),
                      progressColor: theme.colorScheme.primary,
                      strokeWidth: 5,
                    ),
                    child: Center(
                      child: Text(
                        '${(progressPct * 100).toStringAsFixed(0)}%',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
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
                if (cat.quizType == 'vocabulary') {
                  _showTodayStudySheet(context, ref);
                } else {
                  // Map to API category type for practice tab
                  final apiType = cat.quizType == 'grammar'
                      ? 'GRAMMAR'
                      : 'SENTENCE_ARRANGE';
                  context.go('/practice', extra: apiType);
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(LucideIcons.bookOpen,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      cat.ctaLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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

  ProgressStat? _getProgress(String quizType) {
    if (levelProgress == null) return null;
    switch (quizType) {
      case 'vocabulary':
        return levelProgress!.vocabulary;
      case 'grammar':
        return levelProgress!.grammar;
      default:
        return null;
    }
  }

  static String _getAccuracy(TodayStats? today) {
    if (today == null || today.totalAnswers == 0) return '-';
    return ((today.correctAnswers / today.totalAnswers) * 100)
        .toStringAsFixed(0);
  }

  void _showTodayStudySheet(BuildContext context, WidgetRef ref) {
    final previewAsync = ref.read(
      smartPreviewProvider((category: 'VOCABULARY', jlptLevel: jlptLevel)),
    );

    if (!previewAsync.hasValue || previewAsync.value == null) {
      context.go('/practice');
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: AppSizes.sheetShape,
      builder: (_) => TodayStudySheet(
        data: previewAsync.value!,
        jlptLevel: jlptLevel,
      ),
    );
  }

  Future<void> _showDailyGoalSheet(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final goals = [5, 10, 15, 20, 30];
    final selectedGoal = await showModalBottomSheet<int>(
      context: context,
      useRootNavigator: true,
      shape: AppSizes.sheetShape,
      builder: (ctx) {
        return _DailyGoalSheetContent(
          goals: goals,
          currentGoal: dailyGoal,
          theme: theme,
        );
      },
    );

    if (selectedGoal == null || selectedGoal == dailyGoal) return;

    try {
      await ref.read(homeRepositoryProvider).updateDailyGoal(selectedGoal);
      ref.invalidate(profileProvider);
      ref.invalidate(profileDetailProvider);
      ref.invalidate(dashboardProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('하루 목표가 $selectedGoal개로 변경되었습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
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

class _DailyGoalSheetContent extends StatelessWidget {
  final List<int> goals;
  final int currentGoal;
  final ThemeData theme;

  const _DailyGoalSheetContent({
    required this.goals,
    required this.currentGoal,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final theme = this.theme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppSheetHandle(),
            const SizedBox(height: 16),
            Text('하루 목표 설정',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...goals.map((g) {
              final isActive = g == currentGoal;
              return ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                selected: isActive,
                selectedTileColor:
                    theme.colorScheme.primary.withValues(alpha: 0.08),
                title: Text('$g개',
                    style: TextStyle(
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                      color: isActive
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    )),
                trailing: isActive
                    ? Icon(LucideIcons.check,
                        color: theme.colorScheme.primary, size: 20)
                    : null,
                onTap: () => Navigator.of(context).pop(g),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

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
  final String quizType;
  final String ctaLabel;
  final String title;
  const _CategoryInfo({
    required this.icon,
    required this.quizType,
    required this.ctaLabel,
    required this.title,
  });
}
