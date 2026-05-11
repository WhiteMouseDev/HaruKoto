import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/providers/user_preferences_provider.dart';
import '../../study/data/models/quiz_session_model.dart';
import '../../study/providers/study_provider.dart';
import '../../study/presentation/quiz_launch.dart';
import '../../study/presentation/widgets/free_quiz_selection.dart';
import '../../study/presentation/widgets/free_quiz_sheet.dart';

/// Quiz category tabs.
enum _QuizCategory {
  vocabulary('단어', 'VOCABULARY', LucideIcons.languages),
  grammar('문법', 'GRAMMAR', LucideIcons.braces),
  kanji('한자', 'KANJI', LucideIcons.penTool),
  listening('리스닝', 'LISTENING', LucideIcons.headphones),
  sentenceArrange('문장', 'SENTENCE_ARRANGE', LucideIcons.arrowUpDown);

  final String label;
  final String apiType;
  final IconData icon;
  const _QuizCategory(this.label, this.apiType, this.icon);

  /// Free-quiz setup is available for vocabulary and grammar only.
  bool get usesFreeQuizSheet => this == vocabulary || this == grammar;

  String? get defaultMode => this == sentenceArrange ? 'arrange' : null;

  String get modeLabel => switch (this) {
        sentenceArrange => '어순 배열',
        _ => '기본 모드',
      };

  Color get color => switch (this) {
        vocabulary => AppColors.primaryStrong,
        grammar => AppColors.grammar,
        kanji => AppColors.kanji,
        listening => AppColors.listening,
        sentenceArrange => AppColors.sentenceArrange,
      };

  Color get containerColor => switch (this) {
        vocabulary => AppColors.primaryContainer,
        grammar => AppColors.grammarContainer,
        kanji => AppColors.kanjiContainer,
        listening => AppColors.listeningContainer,
        sentenceArrange => AppColors.sentenceArrangeContainer,
      };
}

class PracticePage extends ConsumerStatefulWidget {
  final String? initialCategory;
  const PracticePage({super.key, this.initialCategory});

  @override
  ConsumerState<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends ConsumerState<PracticePage> {
  late _QuizCategory _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = _categoryFromString(widget.initialCategory);
  }

  @override
  void didUpdateWidget(covariant PracticePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCategory != null &&
        widget.initialCategory != oldWidget.initialCategory) {
      setState(() {
        _selectedCategory = _categoryFromString(widget.initialCategory);
      });
    }
  }

  _QuizCategory _categoryFromString(String? category) {
    return _QuizCategory.values.firstWhere(
      (c) => c.apiType == category,
      orElse: () => _QuizCategory.vocabulary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final jlptLevel = ref.watch(userPreferencesProvider).jlptLevel;
    final incompleteAsync = ref.watch(incompleteQuizProvider);
    final incomplete = incompleteAsync.hasValue ? incompleteAsync.value : null;
    final selectedIncomplete =
        incomplete?.quizType == _selectedCategory.apiType ? incomplete : null;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: theme.colorScheme.primary,
          onRefresh: () async {
            ref.invalidate(incompleteQuizProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              // Title
              Text(
                '퀴즈',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // ── Category Tabs ──
              _buildCategoryTabs(theme),
              const SizedBox(height: 20),

              // ── Main CTA Card ──
              _buildCtaCard(
                theme,
                selectedIncomplete,
                jlptLevel,
              ),
              const SizedBox(height: 28),

              // ── Quiz Record Section ──
              Text(
                '퀴즈 기록',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _MenuListTile(
                icon: LucideIcons.fileX,
                iconColor: AppColors.coralPressed,
                label: '오답노트',
                onTap: () => context.push('/study/wrong-answers'),
              ),
              _MenuListTile(
                icon: LucideIcons.bookOpen,
                iconColor: AppColors.primary,
                label: '학습한 단어',
                onTap: () => context.push('/study/learned-words'),
              ),
              _MenuListTile(
                icon: LucideIcons.bookMarked,
                iconColor: AppColors.sentenceArrange,
                label: '단어장',
                onTap: () => context.push('/study/wordbook'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs(ThemeData theme) {
    final isLight = theme.brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isLight
            ? AppColors.quizTabSurface
            : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isLight
              ? AppColors.primary.withValues(alpha: 0.08)
              : theme.colorScheme.outline,
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _QuizCategory.values.map((cat) {
            final isSelected = _selectedCategory == cat;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: isSelected ? 1 : 0),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                builder: (context, selectedValue, _) {
                  final selectedSurface = isLight
                      ? cat.containerColor.withValues(alpha: 0.78)
                      : cat.color.withValues(alpha: 0.18);
                  final backgroundColor = Color.lerp(
                    Colors.transparent,
                    selectedSurface,
                    selectedValue,
                  )!;
                  final iconColor = isSelected
                      ? cat.color
                      : cat.color.withValues(alpha: 0.62);
                  final textColor =
                      isSelected ? cat.color : AppColors.quizTabInactive;
                  final borderColor = Color.lerp(
                    Colors.transparent,
                    cat.color.withValues(alpha: 0.28),
                    selectedValue,
                  )!;

                  return Transform.scale(
                    scale: 1 + (selectedValue * 0.025),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: borderColor),
                          boxShadow: selectedValue > 0
                              ? [
                                  BoxShadow(
                                    color: cat.color.withValues(
                                      alpha: 0.12 * selectedValue,
                                    ),
                                    blurRadius: 12 * selectedValue,
                                    offset: Offset(0, 3 * selectedValue),
                                  ),
                                  BoxShadow(
                                    color: AppColors.overlay(
                                      0.03 * selectedValue,
                                    ),
                                    blurRadius: 4 * selectedValue,
                                    offset: Offset(0, 1 * selectedValue),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(cat.icon, size: 16, color: iconColor),
                            const SizedBox(width: 4),
                            Text(
                              cat.label,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCtaCard(
    ThemeData theme,
    IncompleteSessionModel? incomplete,
    String jlptLevel,
  ) {
    final hasIncomplete = incomplete != null;
    final actionColor =
        hasIncomplete ? AppColors.primaryStrong : _selectedCategory.color;
    final actionContainer = theme.brightness == Brightness.light
        ? (hasIncomplete
            ? AppColors.primaryContainer
            : _selectedCategory.containerColor)
        : theme.colorScheme.surfaceContainerHigh;
    final cardColor = theme.brightness == Brightness.light
        ? AppColors.cardWarm
        : theme.colorScheme.surfaceContainerLow;
    final borderColor = theme.brightness == Brightness.light
        ? actionColor.withValues(alpha: 0.24)
        : theme.colorScheme.outline;
    final ctaTitle =
        hasIncomplete ? '진행 중인 퀴즈 이어풀기' : '${_selectedCategory.label} 퀴즈 풀기';
    final ctaSubtitle = hasIncomplete
        ? '${incomplete.jlptLevel} · ${incomplete.answeredCount}/${incomplete.totalQuestions} 문제 진행 중'
        : '$jlptLevel · 10문제 · ${_selectedCategory.modeLabel}';

    return GestureDetector(
      onTap: () => _startSelectedQuiz(
        context,
        incomplete: incomplete,
        jlptLevel: jlptLevel,
      ),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: 1.0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ctaTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ctaSubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.lightSubtext,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: actionContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasIncomplete
                      ? LucideIcons.playCircle
                      : _selectedCategory.icon,
                  size: 24,
                  color: actionColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startSelectedQuiz(
    BuildContext context, {
    required IncompleteSessionModel? incomplete,
    required String jlptLevel,
  }) async {
    if (incomplete != null) {
      return openQuizPageForSession(
        context,
        quizType: incomplete.quizType,
        jlptLevel: incomplete.jlptLevel,
        count: incomplete.totalQuestions,
        resumeSessionId: incomplete.id,
        mode: _selectedCategory.defaultMode,
      );
    }

    if (_selectedCategory.usesFreeQuizSheet) {
      final selection = await showModalBottomSheet<FreeQuizSelection>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => FreeQuizSheet(
          initialSelection: FreeQuizSelection(
            level: jlptLevel,
            type: _selectedCategory.apiType,
          ),
        ),
      );
      if (selection == null || !context.mounted) return;

      return openQuizPageForSession(
        context,
        quizType: selection.type,
        jlptLevel: selection.level,
        count: 10,
        mode: selection.mode != 'normal' ? selection.mode : null,
      );
    }

    return openQuizPageForSession(
      context,
      quizType: _selectedCategory.apiType,
      jlptLevel: jlptLevel,
      count: 10,
      mode: _selectedCategory.defaultMode,
    );
  }
}

/// Menu list tile item.
class _MenuListTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _MenuListTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}
