import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../data/models/word_entry_model.dart';

class LearnedWordCardDetail extends StatelessWidget {
  final LearnedWordModel word;

  const LearnedWordCardDetail({
    super.key,
    required this.word,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        const SizedBox(height: 12),
        Divider(color: theme.colorScheme.outline, height: 1),
        const SizedBox(height: 12),
        _LearnedWordStats(word: word),
        if (word.exampleSentence != null)
          _LearnedWordExampleSentence(word: word),
        const SizedBox(height: 8),
        Row(
          children: [
            _JlptLevelBadge(level: word.jlptLevel),
          ],
        ),
      ],
    );
  }
}

class _LearnedWordStats extends StatelessWidget {
  final LearnedWordModel word;

  const _LearnedWordStats({required this.word});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _LearnedWordMiniStat(
          label: '정답',
          value: '${word.correctCount}회',
        ),
        const SizedBox(width: 8),
        _LearnedWordMiniStat(
          label: '오답',
          value: '${word.incorrectCount}회',
          isError: true,
        ),
        const SizedBox(width: 8),
        _LearnedWordMiniStat(
          label: '정답률',
          value: '${word.accuracy}%',
        ),
      ],
    );
  }
}

class _LearnedWordMiniStat extends StatelessWidget {
  final String label;
  final String value;
  final bool isError;

  const _LearnedWordMiniStat({
    required this.label,
    required this.value,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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

class _LearnedWordExampleSentence extends StatelessWidget {
  final LearnedWordModel word;

  const _LearnedWordExampleSentence({required this.word});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
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
              Text(word.exampleSentence!, style: theme.textTheme.bodySmall),
              if (word.exampleTranslation != null) ...[
                const SizedBox(height: 4),
                Text(
                  word.exampleTranslation!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _JlptLevelBadge extends StatelessWidget {
  final String level;

  const _JlptLevelBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outline),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        level,
        style: theme.textTheme.labelSmall,
      ),
    );
  }
}
