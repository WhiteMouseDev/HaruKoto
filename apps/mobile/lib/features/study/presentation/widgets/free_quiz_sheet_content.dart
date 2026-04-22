import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../shared/widgets/app_sheet_handle.dart';
import '../../data/models/quiz_session_model.dart';
import 'free_quiz_selection.dart';
import 'jlpt_level_selector.dart';
import 'quiz_mode_selector.dart';
import 'quiz_type_selector.dart';

class FreeQuizSheetContent extends StatelessWidget {
  final FreeQuizSelection selection;
  final StudyStatsModel? stats;
  final ValueChanged<String> onLevelChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onModeChanged;
  final VoidCallback onStartQuiz;

  const FreeQuizSheetContent({
    super.key,
    required this.selection,
    required this.stats,
    required this.onLevelChanged,
    required this.onTypeChanged,
    required this.onModeChanged,
    required this.onStartQuiz,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppSheetHandle(),
            const SizedBox(height: 20),
            Text(
              '자유 퀴즈',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            JlptLevelSelector(
              levels: FreeQuizSelection.jlptLevels,
              selected: selection.level,
              onChanged: onLevelChanged,
            ),
            const SizedBox(height: 16),
            QuizTypeSelector(
              quizTypes: FreeQuizSelection.quizTypes,
              selectedType: selection.type,
              onTypeChanged: onTypeChanged,
            ),
            const SizedBox(height: 16),
            _FreeQuizModeSection(
              selectedMode: selection.mode,
              availableModes: selection.availableModes,
              onChanged: onModeChanged,
            ),
            const SizedBox(height: 20),
            if (stats != null)
              _FreeQuizStatsRow(selection: selection, stats: stats!),
            const SizedBox(height: 20),
            _FreeQuizSheetStartButton(
              modeLabel: selection.modeLabel,
              onStartQuiz: onStartQuiz,
            ),
          ],
        ),
      ),
    );
  }
}

class _FreeQuizModeSection extends StatelessWidget {
  final String selectedMode;
  final List<String> availableModes;
  final ValueChanged<String> onChanged;

  const _FreeQuizModeSection({
    required this.selectedMode,
    required this.availableModes,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '퀴즈 유형',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(height: 8),
        QuizModeSelector(
          selectedMode: selectedMode,
          onChanged: onChanged,
          availableModes: availableModes,
        ),
      ],
    );
  }
}

class _FreeQuizStatsRow extends StatelessWidget {
  final FreeQuizSelection selection;
  final StudyStatsModel stats;

  const _FreeQuizStatsRow({
    required this.selection,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${selection.level} ${selection.contentLabel} · ${stats.totalCount}개',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          Text(
            '진행률 ${stats.progress}%',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FreeQuizSheetStartButton extends StatelessWidget {
  final String modeLabel;
  final VoidCallback onStartQuiz;

  const _FreeQuizSheetStartButton({
    required this.modeLabel,
    required this.onStartQuiz,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: onStartQuiz,
        icon: Icon(
          LucideIcons.play,
          size: 18,
          color: theme.colorScheme.onPrimary,
        ),
        label: Text(
          '$modeLabel 학습 시작 (10문제)',
          style: const TextStyle(
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
    );
  }
}
