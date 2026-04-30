import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/quiz_session_model.dart';
import 'quiz_mode_selector.dart';

class FreeQuizSummaryCard extends StatelessWidget {
  final String selectedLevel;
  final String selectedType;
  final String quizMode;
  final String modeLabel;
  final StudyStatsModel? stats;
  final ValueChanged<String> onModeChanged;
  final VoidCallback onStartQuiz;

  const FreeQuizSummaryCard({
    super.key,
    required this.selectedLevel,
    required this.selectedType,
    required this.quizMode,
    required this.modeLabel,
    required this.stats,
    required this.onModeChanged,
    required this.onStartQuiz,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Column(
        children: [
          _FreeQuizSummaryHeader(
            selectedLevel: selectedLevel,
            selectedType: selectedType,
            modeLabel: modeLabel,
            stats: stats,
          ),
          const SizedBox(height: 16),
          QuizModeSelector(
            selectedMode: quizMode,
            onChanged: onModeChanged,
          ),
          const SizedBox(height: 16),
          _FreeQuizProgress(progress: stats?.progress ?? 0),
          const SizedBox(height: 16),
          _FreeQuizStartButton(onStartQuiz: onStartQuiz),
        ],
      ),
    );
  }
}

class _FreeQuizSummaryHeader extends StatelessWidget {
  final String selectedLevel;
  final String selectedType;
  final String modeLabel;
  final StudyStatsModel? stats;

  const _FreeQuizSummaryHeader({
    required this.selectedLevel,
    required this.selectedType,
    required this.modeLabel,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final isVocabulary = selectedType == 'VOCABULARY';
    final contentLabel = isVocabulary ? '단어' : '문법';
    final accentColor = isVocabulary ? AppColors.sakura : AppColors.purple;
    final accentBg =
        isVocabulary ? AppColors.sakuraTrack : AppColors.purpleTrack;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isLight
                ? accentBg
                : theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isVocabulary ? LucideIcons.bookOpen : LucideIcons.languages,
            size: 20,
            color: isLight ? accentColor : theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$selectedLevel $contentLabel 학습',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                stats != null
                    ? '${stats!.totalCount}개 $contentLabel · $modeLabel'
                    : '$contentLabel · $modeLabel',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isLight
                ? AppColors.mintTrack
                : theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '10문제',
            style: theme.textTheme.labelSmall,
          ),
        ),
      ],
    );
  }
}

class _FreeQuizProgress extends StatelessWidget {
  final int progress;

  const _FreeQuizProgress({required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '학습 진행률',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            Text(
              '$progress%',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress / 100,
            minHeight: 8,
            backgroundColor: isLight
                ? AppColors.sakuraTrack
                : theme.colorScheme.surfaceContainerHigh,
            color: isLight ? AppColors.sakura : theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

class _FreeQuizStartButton extends StatelessWidget {
  final VoidCallback onStartQuiz;

  const _FreeQuizStartButton({required this.onStartQuiz});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton(
        onPressed: onStartQuiz,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('학습 시작하기', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Icon(
              LucideIcons.flower2,
              size: 16,
              color: theme.colorScheme.onPrimary,
            ),
          ],
        ),
      ),
    );
  }
}
