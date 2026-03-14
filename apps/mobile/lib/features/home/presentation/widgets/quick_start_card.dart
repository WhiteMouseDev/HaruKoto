import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/sizes.dart';
import '../../../my/providers/my_provider.dart';
import '../../../study/providers/study_provider.dart';
import '../../data/models/dashboard_model.dart';
import '../../providers/home_provider.dart';

class QuickStartCard extends ConsumerStatefulWidget {
  final LevelProgressData? levelProgress;
  final TodayStats? today;
  final int dailyGoal;

  const QuickStartCard({
    super.key,
    this.levelProgress,
    this.today,
    this.dailyGoal = 10,
  });

  @override
  ConsumerState<QuickStartCard> createState() => _QuickStartCardState();
}

class _QuickStartCardState extends ConsumerState<QuickStartCard> {
  int _selectedIndex = 0;

  static final _categories = [
    _CategoryInfo(
      label: '단어',
      icon: LucideIcons.bookOpen,
      quizType: 'vocabulary',
      ctaLabel: '오늘의 단어',
      title: '단어 학습',
    ),
    _CategoryInfo(
      label: '문법',
      icon: LucideIcons.languages,
      quizType: 'grammar',
      ctaLabel: '오늘의 문법',
      title: '문법 학습',
    ),
    _CategoryInfo(
      label: '문장',
      icon: LucideIcons.arrowUpDown,
      quizType: 'sentence',
      ctaLabel: '오늘의 문장배열',
      title: '문장배열 학습',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Use pure white so card + selected tab are identical
    final cardBg = Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.pageHorizontal),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Main card ──
            Expanded(
              child: _buildMainCard(theme, cardBg),
            ),
            // ── Tab rail (flush, no gap) ──
            _buildTabRail(theme, cardBg),
          ],
        ),
      ),
    );
  }

  Widget _buildMainCard(ThemeData theme, Color cardBg) {
    final cat = _categories[_selectedIndex];
    final progress = _getProgress(cat.quizType);
    final hasProgress = progress != null && progress.total > 0;
    final progressPct =
        hasProgress ? (progress.mastered / progress.total) : 0.0;

    final recAsync = ref.watch(recommendationsProvider);
    final rec = recAsync.hasValue ? recAsync.value : null;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppSizes.cardRadius),
          bottomLeft: Radius.circular(AppSizes.cardRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Category icon ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Container(
                  key: ValueKey('icon_$_selectedIndex'),
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
            child: GestureDetector(
              onTap: () => context.push('/study/wrong-answers'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.checkCircle,
                      size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    hasProgress
                        ? '복습 정답률 ${_getAccuracy()}%'
                        : '복습 정답률 -%',
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
                key: ValueKey('content_$_selectedIndex'),
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
                              '${widget.dailyGoal}개',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => _showDailyGoalSheet(context),
                              child: Icon(
                                LucideIcons.pencil,
                                size: 14,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.4),
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

          // ── Recommendation stats ──
          if (rec != null &&
              (rec.reviewDueCount > 0 || rec.newWordsCount > 0)) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  if (rec.reviewDueCount > 0) ...[
                    _InfoChip(
                      icon: LucideIcons.rotateCw,
                      label: '복습 ${rec.reviewDueCount}개',
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (rec.newWordsCount > 0)
                    _InfoChip(
                      icon: LucideIcons.sparkles,
                      label: '새 단어 ${rec.newWordsCount}개',
                      color: theme.colorScheme.primary,
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ── CTA button ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Material(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                onTap: () => context.go('/study'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.menu_book_rounded,
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
      ),
    );
  }

  // ═════════════════════════════════════════════
  //  Tab rail — no background, individual tabs
  // ═════════════════════════════════════════════
  Widget _buildTabRail(ThemeData theme, Color cardBg) {
    const tabWidth = 52.0;
    final unselectedBg = theme.colorScheme.surfaceContainerHigh;

    return SizedBox(
      width: tabWidth,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: _categories.asMap().entries.map((entry) {
          final i = entry.key;
          final c = entry.value;
          final isSelected = i == _selectedIndex;
          return _TabItem(
            icon: c.icon,
            label: c.label,
            isSelected: isSelected,
            selectedColor: cardBg,
            unselectedColor: unselectedBg,
            isFirst: i == 0,
            isLast: i == _categories.length - 1,
            onTap: () => setState(() => _selectedIndex = i),
          );
        }).toList(),
      ),
    );
  }

  ProgressStat? _getProgress(String quizType) {
    final lp = widget.levelProgress;
    if (lp == null) return null;
    switch (quizType) {
      case 'vocabulary':
        return lp.vocabulary;
      case 'grammar':
        return lp.grammar;
      default:
        return null;
    }
  }

  String _getAccuracy() {
    final today = widget.today;
    if (today == null || today.totalAnswers == 0) return '-';
    return ((today.correctAnswers / today.totalAnswers) * 100)
        .toStringAsFixed(0);
  }

  void _showDailyGoalSheet(BuildContext context) {
    final theme = Theme.of(context);
    final goals = [5, 10, 15, 20, 30];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return _DailyGoalSheetContent(
          goals: goals,
          currentGoal: widget.dailyGoal,
          theme: theme,
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════
//  Daily goal sheet content (stateful for loading)
// ═══════════════════════════════════════════════
class _DailyGoalSheetContent extends ConsumerStatefulWidget {
  final List<int> goals;
  final int currentGoal;
  final ThemeData theme;

  const _DailyGoalSheetContent({
    required this.goals,
    required this.currentGoal,
    required this.theme,
  });

  @override
  ConsumerState<_DailyGoalSheetContent> createState() =>
      _DailyGoalSheetContentState();
}

class _DailyGoalSheetContentState
    extends ConsumerState<_DailyGoalSheetContent> {
  bool _isLoading = false;

  Future<void> _onGoalSelected(int goal) async {
    if (goal == widget.currentGoal || _isLoading) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(homeRepositoryProvider).updateDailyGoal(goal);
      // Invalidate providers to refresh the UI
      ref.invalidate(profileProvider);
      ref.invalidate(profileDetailProvider);
      ref.invalidate(dashboardProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('하루 목표가 $goal개로 변경되었습니다'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('목표 변경에 실패했습니다. 다시 시도해주세요.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '하루 목표 설정',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...widget.goals.map((g) {
              final isActive = g == widget.currentGoal;
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                selected: isActive,
                selectedTileColor:
                    theme.colorScheme.primary.withValues(alpha: 0.08),
                title: Text(
                  '$g개',
                  style: TextStyle(
                    fontWeight:
                        isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
                trailing: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : isActive
                        ? Icon(LucideIcons.check,
                            color: theme.colorScheme.primary, size: 20)
                        : null,
                enabled: !_isLoading,
                onTap: () => _onGoalSelected(g),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  Tab item
// ═══════════════════════════════════════════════
class _TabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color selectedColor;
  final Color unselectedColor;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _TabItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.selectedColor,
    required this.unselectedColor,
    this.isFirst = false,
    this.isLast = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Selected: flush left, rounded right (connects to card)
    // Unselected: rounded right only, looks like a folder tab sticking out
    final borderRadius = BorderRadius.only(
      topRight: Radius.circular(isFirst ? 16 : 12),
      bottomRight: Radius.circular(isLast ? 16 : 12),
    );

    return Material(
      color: isSelected ? selectedColor : unselectedColor,
      borderRadius: borderRadius,
      // Unselected tabs get subtle shadow = "sitting on top" of the folder
      elevation: isSelected ? 0 : 1,
      shadowColor: isSelected
          ? Colors.transparent
          : Colors.black.withValues(alpha: 0.15),
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  Circular progress painter
// ═══════════════════════════════════════════════
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryInfo {
  final String label;
  final IconData icon;
  final String quizType;
  final String ctaLabel;
  final String title;

  const _CategoryInfo({
    required this.label,
    required this.icon,
    required this.quizType,
    required this.ctaLabel,
    required this.title,
  });
}
