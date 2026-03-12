import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/kana_character_model.dart';
import 'kana_flashcard.dart';

class StageReview extends StatelessWidget {
  final KanaCharacterModel character;
  final int currentIndex;
  final int totalCount;
  final VoidCallback onAdvance;

  const StageReview({
    super.key,
    required this.character,
    required this.currentIndex,
    required this.totalCount,
    required this.onAdvance,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Row(
          children: [
            Icon(LucideIcons.rotateCcw,
                size: 14,
                color: theme.colorScheme.onSurface
                    .withValues(alpha: 0.5)),
            const SizedBox(width: 6),
            Text(
              '복습',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface
                    .withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (currentIndex + 1) / totalCount,
                  minHeight: 6,
                  backgroundColor:
                      theme.colorScheme.surfaceContainerHigh,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${currentIndex + 1}/$totalCount',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface
                    .withValues(alpha: 0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.lg),
        Expanded(
          child: Center(
            child: KanaFlashcard(
              key: ValueKey('review-$currentIndex'),
              character: character.character,
              romaji: character.romaji,
              pronunciation: character.pronunciation,
              exampleWord: character.exampleWord,
              exampleReading: character.exampleReading,
              exampleMeaning: character.exampleMeaning,
              onKnow: onAdvance,
              onDontKnow: onAdvance,
            ),
          ),
        ),
      ],
    );
  }
}
