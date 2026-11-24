import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/text_theme.dart';
import '../../../../shared/widgets/app_sheet_handle.dart';
import '../../data/models/quiz_session_model.dart';
import 'free_quiz_selection.dart';

class FreeQuizSheetContent extends StatelessWidget {
  final FreeQuizSelection selection;
  final StudyStatsModel? stats;
  final bool statsLoading;
  final VoidCallback? onRetryStats;
  final ValueChanged<String> onLevelChanged;
  final ValueChanged<String> onModeChanged;
  final VoidCallback onStartQuiz;

  const FreeQuizSheetContent({
    super.key,
    required this.selection,
    required this.stats,
    required this.statsLoading,
    required this.onRetryStats,
    required this.onLevelChanged,
    required this.onModeChanged,
    required this.onStartQuiz,
  });

  static const _modeIcons = {
    'normal': LucideIcons.listChecks,
    'matching': LucideIcons.shuffle,
    'cloze': LucideIcons.textCursorInput,
    'arrange': LucideIcons.arrowUpDown,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final heading = TextStyle(
      fontFamily: redesignFontFamily,
      color: light ? AppColors.redesignForeground : theme.colorScheme.onSurface,
      fontSize: 16,
      height: 1.4,
      fontWeight: FontWeight.w600,
    );

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSheetHandle(),
            const SizedBox(height: 20),
            Semantics(
              header: true,
              child: Text(
                '${selection.contentLabel} 퀴즈 풀기',
                textAlign: TextAlign.center,
                style: heading.copyWith(fontSize: 20),
              ),
            ),
            const SizedBox(height: 20),
            Text('퀴즈 난이도', style: heading),
            const SizedBox(height: 8),
            _FreeQuizChoices(
              choices: FreeQuizSelection.jlptLevels,
              selected: selection.level,
              columnLimit: FreeQuizSelection.jlptLevels.length,
              onChanged: onLevelChanged,
            ),
            const SizedBox(height: 6),
            _FreeQuizStatsStrip(
              label: selection.contentLabel,
              stats: stats,
              loading: statsLoading,
              onRetry: onRetryStats,
            ),
            const SizedBox(height: 22),
            Text('퀴즈 유형', style: heading),
            const SizedBox(height: 8),
            _FreeQuizChoices(
              choices: selection.availableModes,
              selected: selection.mode,
              columnLimit: 2,
              labels: FreeQuizSelection.modeLabels,
              icons: _modeIcons,
              onChanged: onModeChanged,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onStartQuiz,
              style: FilledButton.styleFrom(
                backgroundColor: light ? AppColors.brandPink : null,
                foregroundColor: light ? Colors.white : null,
                minimumSize: const Size(0, 48),
                shape: const StadiumBorder(),
                textStyle: heading.copyWith(fontSize: 14),
              ),
              child: const Text('퀴즈 시작', textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

class _FreeQuizChoices extends StatelessWidget {
  final List<String> choices;
  final String selected;
  final int columnLimit;
  final Map<String, String> labels;
  final Map<String, IconData> icons;
  final ValueChanged<String> onChanged;

  const _FreeQuizChoices({
    required this.choices,
    required this.selected,
    required this.columnLimit,
    this.labels = const {},
    this.icons = const {},
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const spacing = 4.0;
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final accent = light ? AppColors.brandPink : theme.colorScheme.primary;
    final foreground =
        light ? AppColors.redesignForeground : theme.colorScheme.onSurface;
    final outline =
        light ? AppColors.redesignOutline : theme.colorScheme.outline;
    final fontSize = MediaQuery.textScalerOf(context).scale(14);
    final minWidth = icons.isEmpty
        ? (fontSize * 1.4 + 16).clamp(48.0, double.infinity)
        : fontSize * 3.6 + 36;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            ((constraints.maxWidth + spacing) / (minWidth + spacing))
                .floor()
                .clamp(1, columnLimit);
        final width =
            (constraints.maxWidth - (columns - 1) * spacing) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final choice in choices)
              SizedBox(
                width: width,
                child: MergeSemantics(
                  child: Semantics(
                    selected: choice == selected,
                    child: OutlinedButton(
                      onPressed: () => onChanged(choice),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            choice == selected ? accent : foreground,
                        side: BorderSide(
                          color: choice == selected ? accent : outline,
                        ),
                        minimumSize: const Size(0, 42),
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        textStyle: const TextStyle(
                          fontFamily: redesignFontFamily,
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (icons[choice] case final icon?) ...[
                            Icon(icon, size: 14),
                            const SizedBox(width: 6),
                          ],
                          Flexible(
                            child: Text(
                              labels[choice] ?? choice,
                              textAlign: TextAlign.center,
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
      },
    );
  }
}

class _FreeQuizStatsStrip extends StatelessWidget {
  final String label;
  final StudyStatsModel? stats;
  final bool loading;
  final VoidCallback? onRetry;

  const _FreeQuizStatsStrip({
    required this.label,
    required this.stats,
    required this.loading,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final current = stats;
    final countFormat = MaterialLocalizations.of(context).formatDecimal;

    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: light
            ? AppColors.redesignSurface
            : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.centerLeft,
      child: DefaultTextStyle(
        style: TextStyle(
          fontFamily: redesignFontFamily,
          color: light
              ? AppColors.redesignForeground
              : theme.colorScheme.onSurface,
          fontSize: 12,
          height: 1.4,
        ),
        child: SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              if (current != null) ...[
                Text('$label ${countFormat(current.totalCount)}개'),
                Text(
                  '진행률 ${countFormat(current.progress)}%',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ] else
                Text(loading ? '진행률 불러오는 중' : '진행률을 불러오지 못했어요'),
              if (onRetry case final retry?)
                TextButton(
                  onPressed: retry,
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('다시 시도'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
