import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/providers/user_preferences_provider.dart';
import '../../study/data/models/quiz_session_model.dart';
import '../../study/data/models/smart_preview_model.dart';
import '../../study/providers/study_provider.dart';
import '../../study/presentation/study_entry_flow.dart';

/// Quiz category tabs.
enum _QuizCategory {
  vocabulary('단어', 'VOCABULARY', LucideIcons.languages),
  grammar('문법', 'GRAMMAR', LucideIcons.braces),
  kanji('한자', 'KANJI', LucideIcons.penTool),
  listening('리스닝', 'LISTENING', LucideIcons.headphones),
  sentenceArrange('문장배열', 'SENTENCE_ARRANGE', LucideIcons.arrowUpDown);

  final String label;
  final String apiType;
  final IconData icon;
  const _QuizCategory(this.label, this.apiType, this.icon);

  /// Smart preview/start is available for vocabulary and grammar only
  bool get hasSmart => this == vocabulary || this == grammar;

  Color get color => switch (this) {
        vocabulary => AppColors.primaryStrong,
        grammar => AppColors.grammar,
        kanji => AppColors.kanji,
        listening => AppColors.neutralOn,
        sentenceArrange => AppColors.kanji,
      };

  Color get containerColor => switch (this) {
        vocabulary => AppColors.primaryContainer,
        grammar => AppColors.grammarContainer,
        kanji => AppColors.kanjiContainer,
        listening => AppColors.neutralContainer,
        sentenceArrange => AppColors.kanjiContainer,
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

    // Prefetch both VOCABULARY and GRAMMAR previews for smooth tab switching
    final vocabPreviewAsync = ref.watch(
        smartPreviewProvider((category: 'VOCABULARY', jlptLevel: jlptLevel)));
    final grammarPreviewAsync = ref.watch(
        smartPreviewProvider((category: 'GRAMMAR', jlptLevel: jlptLevel)));

    // Use the preview for the currently selected category
    final previewAsync = switch (_selectedCategory) {
      _QuizCategory.vocabulary => vocabPreviewAsync,
      _QuizCategory.grammar => grammarPreviewAsync,
      _QuizCategory.kanji ||
      _QuizCategory.listening ||
      _QuizCategory.sentenceArrange =>
        null,
    };

    final incomplete = incompleteAsync.hasValue ? incompleteAsync.value : null;
    final preview = previewAsync?.hasValue == true ? previewAsync!.value : null;
    final decision = resolveStudyEntryDecision(
      category: _selectedCategory.apiType,
      hasIncomplete: incomplete != null && _selectedCategory.hasSmart,
      hasPreview: preview != null,
    );

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: theme.colorScheme.primary,
          onRefresh: () async {
            ref.invalidate(incompleteQuizProvider);
            ref.invalidate(smartPreviewProvider(
                (category: 'VOCABULARY', jlptLevel: jlptLevel)));
            ref.invalidate(smartPreviewProvider(
                (category: 'GRAMMAR', jlptLevel: jlptLevel)));
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
                incomplete,
                preview,
                previewAsync,
                jlptLevel,
                decision,
              ),
              const SizedBox(height: 28),

              // ── Study Management Section ──
              Text(
                '학습 관리',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _MenuListTile(
                icon: LucideIcons.fileX,
                iconColor: AppColors.error(theme.brightness),
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
                iconColor: AppColors.neutralOn,
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light
            ? AppColors.surfaceMuted
            : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _QuizCategory.values.map((cat) {
            final isSelected = _selectedCategory == cat;
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.lightCard : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      cat.icon,
                      size: 16,
                      color: isSelected ? cat.color : AppColors.lightSubtext,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      cat.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? cat.color : AppColors.lightSubtext,
                      ),
                    ),
                  ],
                ),
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
    SmartPreviewModel? preview,
    AsyncValue<SmartPreviewModel>? previewAsync,
    String jlptLevel,
    StudyEntryDecision decision,
  ) {
    final hasIncomplete = decision.action == StudyEntryActionKind.resumeOrNew;
    final isSmartLoading = _selectedCategory.hasSmart &&
        previewAsync != null &&
        previewAsync.isLoading &&
        preview == null;
    final isTappable = !isSmartLoading && decision.isTappable;
    final todayCompleted = preview?.todayCompleted ?? 0;
    final dailyGoal = preview?.dailyGoal ?? 20;
    final completedPct =
        dailyGoal > 0 ? (todayCompleted / dailyGoal).clamp(0.0, 1.0) : 0.0;
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
        ? AppColors.lightBorder
        : theme.colorScheme.outline;

    // CTA text based on category
    final ctaTitle =
        hasIncomplete ? '이어서 학습하기' : '오늘의 ${_selectedCategory.label} 학습';

    final String ctaSubtitle;
    if (hasIncomplete) {
      final session = incomplete!;
      ctaSubtitle =
          '${session.answeredCount}/${session.totalQuestions} 문제 진행 중';
    } else if (!_selectedCategory.hasSmart) {
      ctaSubtitle = '${_selectedCategory.label} 10문제';
    } else if (isSmartLoading) {
      ctaSubtitle = '불러오는 중...';
    } else {
      ctaSubtitle = '하루 목표 $dailyGoal개 · $todayCompleted/$dailyGoal';
    }

    return GestureDetector(
      onTap: isTappable
          ? () => executeStudyEntryDecision(
                context,
                decision: decision,
                category: _selectedCategory.apiType,
                jlptLevel: jlptLevel,
                incomplete: incomplete,
                preview: preview,
              )
          : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isTappable ? 1.0 : 0.6,
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
                    if (!hasIncomplete &&
                        _selectedCategory.hasSmart &&
                        todayCompleted > 0) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: completedPct,
                          minHeight: 6,
                          backgroundColor: AppColors.surfaceMuted,
                          color: actionColor,
                        ),
                      ),
                    ],
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
                color: iconColor.withValues(alpha: 0.12),
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
