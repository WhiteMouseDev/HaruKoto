import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/quiz_session_model.dart';
import 'jlpt_level_selector.dart';
import 'quiz_mode_selector.dart';
import 'quiz_type_selector.dart';

class FreeTab extends StatelessWidget {
  final String selectedLevel;
  final String selectedType;
  final String quizMode;
  final String modeLabel;
  final List<String> jlptLevels;
  final List<(String, String)> quizTypes;
  final AsyncValue<StudyStatsModel> statsAsync;
  final ValueChanged<String> onLevelChanged;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onModeChanged;
  final VoidCallback onStartQuiz;

  const FreeTab({
    super.key,
    required this.selectedLevel,
    required this.selectedType,
    required this.quizMode,
    required this.modeLabel,
    required this.jlptLevels,
    required this.quizTypes,
    required this.statsAsync,
    required this.onLevelChanged,
    required this.onTypeChanged,
    required this.onModeChanged,
    required this.onStartQuiz,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = statsAsync.hasValue ? statsAsync.value : null;

    return Column(
      children: [
        JlptLevelSelector(
          levels: jlptLevels,
          selected: selectedLevel,
          onChanged: onLevelChanged,
        ),
        const SizedBox(height: 12),
        QuizTypeSelector(
          quizTypes: quizTypes,
          selectedType: selectedType,
          onTypeChanged: onTypeChanged,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      selectedType == 'VOCABULARY'
                          ? LucideIcons.bookOpen
                          : LucideIcons.languages,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$selectedLevel ${selectedType == 'VOCABULARY' ? '단어' : '문법'} 학습',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          stats != null
                              ? '${stats.totalCount}개 ${selectedType == 'VOCABULARY' ? '단어' : '문법'} · $modeLabel'
                              : '${selectedType == 'VOCABULARY' ? '단어' : '문법'} · $modeLabel',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '10문제',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              QuizModeSelector(
                selectedMode: quizMode,
                onChanged: onModeChanged,
              ),
              const SizedBox(height: 16),
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '학습 진행률',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      Text(
                        '${stats?.progress ?? 0}%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (stats?.progress ?? 0) / 100,
                      minHeight: 8,
                      backgroundColor: theme.colorScheme.surfaceContainerHigh,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: onStartQuiz,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('학습 시작하기', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Icon(LucideIcons.flower2,
                          size: 16, color: theme.colorScheme.onPrimary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
