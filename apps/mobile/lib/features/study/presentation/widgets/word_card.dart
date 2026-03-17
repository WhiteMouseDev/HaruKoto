import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../../../shared/widgets/tts_play_button.dart';
import '../../data/models/word_entry_model.dart';

class WordCard extends StatelessWidget {
  final LearnedWordModel word;
  final bool expanded;
  final VoidCallback onTap;

  const WordCard({
    super.key,
    required this.word,
    this.expanded = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outline),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              word.word,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            TtsPlayButton(
                              vocabId: word.vocabularyId,
                              iconSize: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              word.reading,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          word.meaningKo,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: word.mastered
                          ? theme.colorScheme.primary.withValues(alpha: 0.1)
                          : AppColors.info(theme.brightness)
                              .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      word.mastered ? '마스터' : '학습중',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: word.mastered
                            ? theme.colorScheme.primary
                            : AppColors.info(theme.brightness),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              // Expanded detail
              if (expanded) ...[
                const SizedBox(height: 12),
                Divider(color: theme.colorScheme.outline, height: 1),
                const SizedBox(height: 12),

                // Stats
                Row(
                  children: [
                    _MiniStat(
                      label: '정답',
                      value: '${word.correctCount}회',
                      theme: theme,
                    ),
                    const SizedBox(width: 8),
                    _MiniStat(
                      label: '오답',
                      value: '${word.incorrectCount}회',
                      theme: theme,
                      isError: true,
                    ),
                    const SizedBox(width: 8),
                    _MiniStat(
                      label: '정답률',
                      value: '${word.accuracy}%',
                      theme: theme,
                    ),
                  ],
                ),

                if (word.exampleSentence != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(word.exampleSentence!,
                            style: theme.textTheme.bodySmall),
                        if (word.exampleTranslation != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            word.exampleTranslation!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                // Level badge
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outline),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        word.jlptLevel,
                        style: theme.textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final ThemeData theme;
  final bool isError;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.theme,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isError ? AppColors.error(theme.brightness) : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
