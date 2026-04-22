import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../shared/widgets/tts_play_button.dart';
import '../../data/models/word_entry_model.dart';

class LearnedWordCardHeader extends StatelessWidget {
  final LearnedWordModel word;

  const LearnedWordCardHeader({
    super.key,
    required this.word,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
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
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                word.meaningKo,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        LearnedWordStatusBadge(mastered: word.mastered),
      ],
    );
  }
}

class LearnedWordStatusBadge extends StatelessWidget {
  final bool mastered;

  const LearnedWordStatusBadge({
    super.key,
    required this.mastered,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        mastered ? theme.colorScheme.primary : AppColors.info(theme.brightness);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        mastered ? '마스터' : '학습중',
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
