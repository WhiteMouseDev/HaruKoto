import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/colors.dart';
import '../../home/providers/home_provider.dart';
import '../../study/data/models/quiz_session_model.dart';
import '../../study/data/models/smart_preview_model.dart';
import '../../study/providers/study_provider.dart';
import '../../study/presentation/quiz_page.dart';
import '../../study/presentation/widgets/today_study_sheet.dart';

/// Quiz category tabs.
enum _QuizCategory {
  vocabulary('단어', 'VOCABULARY', LucideIcons.languages),
  grammar('문법', 'GRAMMAR', LucideIcons.braces),
  sentenceArrange('문장배열', 'SENTENCE_ARRANGE', LucideIcons.arrowUpDown);

  final String label;
  final String apiType;
  final IconData icon;
  const _QuizCategory(this.label, this.apiType, this.icon);

  bool get hasSmart => this != sentenceArrange;
}

class PracticePage extends ConsumerStatefulWidget {
  const PracticePage({super.key});

  @override
  ConsumerState<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends ConsumerState<PracticePage> {
  _QuizCategory _selectedCategory = _QuizCategory.vocabulary;

  void _showTodayStudySheet(SmartPreviewModel data, String jlptLevel) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TodayStudySheet(
        data: data,
        jlptLevel: jlptLevel,
      ),
    );
  }

  void _handleCtaTap({
    IncompleteSessionModel? incomplete,
    SmartPreviewModel? preview,
    required String jlptLevel,
  }) {
    // For non-smart categories, launch directly
    if (!_selectedCategory.hasSmart) {
      Navigator.of(context, rootNavigator: true).push(
        quizRoute(QuizPage(
          quizType: _selectedCategory.apiType,
          jlptLevel: jlptLevel,
          count: 10,
          mode: 'arrange',
        )),
      );
      return;
    }

    if (incomplete != null) {
      _showResumeOrNewSheet(incomplete, preview, jlptLevel);
      return;
    }
    if (preview != null) {
      _showTodayStudySheet(preview, jlptLevel);
    }
  }

  void _showResumeOrNewSheet(
    IncompleteSessionModel session,
    SmartPreviewModel? preview,
    String jlptLevel,
  ) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
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
                const SizedBox(height: 20),
                Text(
                  '진행 중인 학습이 있어요',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${session.jlptLevel} ${session.quizType == 'VOCABULARY' ? '단어' : '문법'} · ${session.answeredCount}/${session.totalQuestions} 문제 진행',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.lightSubtext,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.of(context, rootNavigator: true).push(
                        quizRoute(QuizPage(resumeSessionId: session.id)),
                      );
                    },
                    icon: const Icon(LucideIcons.playCircle, size: 18),
                    label: const Text(
                      '이어서 학습하기',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (preview != null) {
                        _showTodayStudySheet(preview, jlptLevel);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      '새로 시작하기',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(profileProvider);
    final jlptLevel =
        profileAsync.hasValue ? profileAsync.value!.jlptLevel : 'N5';

    final incompleteAsync = ref.watch(incompleteQuizProvider);

    // Only fetch smart preview for smart-capable categories
    final previewAsync = _selectedCategory.hasSmart
        ? ref.watch(smartPreviewProvider(
            (category: _selectedCategory.apiType, jlptLevel: jlptLevel)))
        : null;

    final incomplete = incompleteAsync.hasValue ? incompleteAsync.value : null;
    final preview = previewAsync?.hasValue == true ? previewAsync!.value : null;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: theme.colorScheme.primary,
          onRefresh: () async {
            ref.invalidate(incompleteQuizProvider);
            ref.invalidate(profileProvider);
            if (_selectedCategory.hasSmart) {
              ref.invalidate(smartPreviewProvider(
                  (category: _selectedCategory.apiType, jlptLevel: jlptLevel)));
            }
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
                  theme, incomplete, preview, previewAsync, jlptLevel),
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
                iconColor: AppColors.primaryStrong,
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
                iconColor: AppColors.primaryStrong,
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
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: _QuizCategory.values.map((cat) {
          final isSelected = _selectedCategory == cat;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.lightCard : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.12),
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
                      color: isSelected
                          ? AppColors.primaryStrong
                          : AppColors.lightSubtext,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      cat.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? AppColors.primaryStrong
                            : AppColors.lightSubtext,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCtaCard(
    ThemeData theme,
    IncompleteSessionModel? incomplete,
    SmartPreviewModel? preview,
    AsyncValue<SmartPreviewModel>? previewAsync,
    String jlptLevel,
  ) {
    // Loading state (smart categories only)
    if (_selectedCategory.hasSmart &&
        previewAsync != null &&
        previewAsync.isLoading &&
        preview == null) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
      );
    }

    final hasIncomplete = incomplete != null && _selectedCategory.hasSmart;
    final todayCompleted = preview?.todayCompleted ?? 0;
    final dailyGoal = preview?.dailyGoal ?? 20;
    final completedPct =
        dailyGoal > 0 ? (todayCompleted / dailyGoal).clamp(0.0, 1.0) : 0.0;

    // CTA text based on category
    final ctaTitle =
        hasIncomplete ? '이어서 학습하기' : '오늘의 ${_selectedCategory.label} 학습';

    final ctaSubtitle = hasIncomplete
        ? '${incomplete.answeredCount}/${incomplete.totalQuestions} 문제 진행 중'
        : _selectedCategory.hasSmart
            ? '하루 목표 $dailyGoal개 · $todayCompleted/$dailyGoal'
            : '${_selectedCategory.label} 10문제';

    return GestureDetector(
      onTap: () => _handleCtaTap(
          incomplete: incomplete, preview: preview, jlptLevel: jlptLevel),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: hasIncomplete
                ? [
                    AppColors.primaryStrong.withValues(alpha: 0.14),
                    AppColors.primary.withValues(alpha: 0.08),
                  ]
                : [
                    AppColors.primary.withValues(alpha: 0.10),
                    AppColors.primary.withValues(alpha: 0.04),
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasIncomplete
                ? AppColors.primaryStrong.withValues(alpha: 0.3)
                : AppColors.primary.withValues(alpha: 0.2),
          ),
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
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.12),
                        color: AppColors.primaryStrong,
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
                color: AppColors.primary.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasIncomplete ? LucideIcons.playCircle : _selectedCategory.icon,
                size: 24,
                color: AppColors.primaryStrong,
              ),
            ),
          ],
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
