import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/colors.dart';
import '../../study/data/models/quiz_session_model.dart';
import '../../study/data/models/smart_preview_model.dart';
import '../../study/providers/study_provider.dart';
import '../../study/presentation/quiz_page.dart';
import '../../study/presentation/widgets/today_study_sheet.dart';
import '../../study/presentation/widgets/free_quiz_sheet.dart';

class PracticePage extends ConsumerStatefulWidget {
  const PracticePage({super.key});

  @override
  ConsumerState<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends ConsumerState<PracticePage> {
  final String _selectedLevel = 'N5';

  void _showTodayStudySheet(SmartPreviewModel data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TodayStudySheet(
        data: data,
        jlptLevel: _selectedLevel,
      ),
    );
  }

  void _showFreeQuizSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const FreeQuizSheet(),
    );
  }

  void _handleCtaTap({
    IncompleteSessionModel? incomplete,
    SmartPreviewModel? preview,
  }) {
    // If incomplete session exists, show choice bottom sheet
    if (incomplete != null) {
      _showResumeOrNewSheet(incomplete, preview);
      return;
    }
    // Otherwise show today's study sheet
    if (preview != null) {
      _showTodayStudySheet(preview);
    }
  }

  void _showResumeOrNewSheet(
    IncompleteSessionModel session,
    SmartPreviewModel? preview,
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
                // Handle
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
                // Resume button
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
                // New session button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (preview != null) {
                        _showTodayStudySheet(preview);
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
    final incompleteAsync = ref.watch(incompleteQuizProvider);
    final previewAsync = ref.watch(
      smartPreviewProvider(
          (category: 'VOCABULARY', jlptLevel: _selectedLevel)),
    );

    final incomplete =
        incompleteAsync.hasValue ? incompleteAsync.value : null;
    final preview = previewAsync.hasValue ? previewAsync.value : null;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: theme.colorScheme.primary,
          onRefresh: () async {
            ref.invalidate(incompleteQuizProvider);
            ref.invalidate(
              smartPreviewProvider(
                  (category: 'VOCABULARY', jlptLevel: _selectedLevel)),
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
              _buildCtaCard(theme, incomplete, preview, previewAsync),
              const SizedBox(height: 28),

              // ── Menu Section ──
              _MenuListTile(
                icon: LucideIcons.fileX,
                iconColor: theme.colorScheme.error,
                label: '오답노트',
                onTap: () => context.push('/study/wrong-answers'),
              ),
              _MenuListTile(
                icon: LucideIcons.bookOpen,
                iconColor: theme.colorScheme.primary,
                label: '학습한 단어',
                onTap: () => context.push('/study/learned-words'),
              ),
              _MenuListTile(
                icon: LucideIcons.bookMarked,
                iconColor: const Color(0xFFF59E0B),
                label: '단어장',
                onTap: () => context.push('/study/wordbook'),
              ),
              Divider(
                color: theme.colorScheme.outline.withValues(alpha: 0.15),
                height: 16,
              ),
              _MenuListTile(
                icon: LucideIcons.dices,
                iconColor: const Color(0xFF8B5CF6),
                label: '자유 퀴즈',
                subtitle: '레벨 · 유형 · 모드 직접 선택',
                onTap: _showFreeQuizSheet,
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
  ) {
    // Loading state
    if (previewAsync.isLoading && preview == null) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
      );
    }

    // Determine card content based on state
    final hasIncomplete = incomplete != null;
    final todayCompleted = preview?.todayCompleted ?? 0;
    final dailyGoal = preview?.dailyGoal ?? 20;
    final completedPct =
        dailyGoal > 0 ? (todayCompleted / dailyGoal).clamp(0.0, 1.0) : 0.0;

    return GestureDetector(
      onTap: () => _handleCtaTap(incomplete: incomplete, preview: preview),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: hasIncomplete
                ? [
                    const Color(0xFFFEF3C7),
                    const Color(0xFFFDE68A).withValues(alpha: 0.6),
                  ]
                : [
                    theme.colorScheme.primary.withValues(alpha: 0.08),
                    theme.colorScheme.primary.withValues(alpha: 0.04),
                  ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasIncomplete
                ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                : theme.colorScheme.primary.withValues(alpha: 0.15),
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
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                    )
                  else
                    Text(
                      '하루 목표 $dailyGoal개 · $todayCompleted/$dailyGoal',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  if (!hasIncomplete && todayCompleted > 0) ...[
                    const SizedBox(height: 10),
                    // Mini progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: completedPct,
                        minHeight: 6,
                        backgroundColor:
                            theme.colorScheme.primary.withValues(alpha: 0.12),
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
                color: hasIncomplete
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                    : theme.colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasIncomplete ? LucideIcons.playCircle : LucideIcons.play,
                size: 24,
                color: hasIncomplete
                    ? const Color(0xFFF59E0B)
                    : theme.colorScheme.primary,
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
  final String? subtitle;
  final VoidCallback onTap;

  const _MenuListTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.subtitle,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4),
                      ),
                    ),
                ],
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
