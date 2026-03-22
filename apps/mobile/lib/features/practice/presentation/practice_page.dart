import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../home/providers/home_provider.dart';
import '../../study/data/models/quiz_session_model.dart';
import '../../study/data/models/smart_preview_model.dart';
import '../../study/providers/study_provider.dart';
import '../../study/presentation/quiz_page.dart';
import '../../study/presentation/widgets/today_study_sheet.dart';

class PracticePage extends ConsumerStatefulWidget {
  const PracticePage({super.key});

  @override
  ConsumerState<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends ConsumerState<PracticePage> {
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
    if (incomplete != null) {
      _showResumeOrNewSheet(incomplete, preview, jlptLevel);
      return;
    }
    if (preview != null) {
      _showTodayStudySheet(preview, jlptLevel);
    }
  }

  void _launchQuickQuiz({
    required String quizType,
    required String jlptLevel,
    String? mode,
  }) {
    Navigator.of(context, rootNavigator: true).push(
      quizRoute(QuizPage(
        quizType: quizType,
        jlptLevel: jlptLevel,
        count: 10,
        mode: mode,
      )),
    );
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
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
    final previewAsync = ref.watch(
      smartPreviewProvider((category: 'VOCABULARY', jlptLevel: jlptLevel)),
    );

    final incomplete = incompleteAsync.hasValue ? incompleteAsync.value : null;
    final preview = previewAsync.hasValue ? previewAsync.value : null;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: theme.colorScheme.primary,
          onRefresh: () async {
            ref.invalidate(incompleteQuizProvider);
            ref.invalidate(profileProvider);
            ref.invalidate(
              smartPreviewProvider(
                  (category: 'VOCABULARY', jlptLevel: jlptLevel)),
            );
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
              const SizedBox(height: 20),

              // ── Main CTA Card ──
              _buildCtaCard(
                  theme, incomplete, preview, previewAsync, jlptLevel),
              const SizedBox(height: 24),

              // ── Quick Start Section ──
              Text(
                '빠른 시작',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _QuickStartChip(
                    icon: LucideIcons.languages,
                    label: '단어',
                    onTap: () => _launchQuickQuiz(
                      quizType: 'VOCABULARY',
                      jlptLevel: jlptLevel,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _QuickStartChip(
                    icon: LucideIcons.braces,
                    label: '문법',
                    onTap: () => _launchQuickQuiz(
                      quizType: 'GRAMMAR',
                      jlptLevel: jlptLevel,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _QuickStartChip(
                    icon: LucideIcons.arrowUpDown,
                    label: '문장배열',
                    onTap: () => _launchQuickQuiz(
                      quizType: 'SENTENCE_ARRANGE',
                      jlptLevel: jlptLevel,
                      mode: 'arrange',
                    ),
                  ),
                ],
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

  Widget _buildCtaCard(
    ThemeData theme,
    IncompleteSessionModel? incomplete,
    SmartPreviewModel? preview,
    AsyncValue<SmartPreviewModel> previewAsync,
    String jlptLevel,
  ) {
    if (previewAsync.isLoading && preview == null) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
      );
    }

    final hasIncomplete = incomplete != null;
    final todayCompleted = preview?.todayCompleted ?? 0;
    final dailyGoal = preview?.dailyGoal ?? 20;
    final completedPct =
        dailyGoal > 0 ? (todayCompleted / dailyGoal).clamp(0.0, 1.0) : 0.0;

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
                    hasIncomplete ? '이어서 학습하기' : '오늘의 학습',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (hasIncomplete)
                    Text(
                      '${incomplete.answeredCount}/${incomplete.totalQuestions} 문제 진행 중',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.lightSubtext,
                      ),
                    )
                  else
                    Text(
                      '하루 목표 $dailyGoal개 · $todayCompleted/$dailyGoal',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.lightSubtext,
                      ),
                    ),
                  if (!hasIncomplete && todayCompleted > 0) ...[
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
                hasIncomplete ? LucideIcons.playCircle : LucideIcons.play,
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

/// Quick start chip for launching quizzes directly.
class _QuickStartChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickStartChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.lightCard,
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            border: Border.all(color: AppColors.lightBorder),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: AppColors.primaryStrong),
              const SizedBox(height: 6),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.lightText,
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
