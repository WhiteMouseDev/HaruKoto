import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../shared/widgets/tts_play_button.dart';
import '../../data/models/kana_character_model.dart';
import 'progress_row.dart';

class StageIntro extends StatelessWidget {
  final KanaCharacterModel character;
  final int currentIndex;
  final int totalCount;
  final VoidCallback onNext;

  const StageIntro({
    super.key,
    required this.character,
    required this.currentIndex,
    required this.totalCount,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = currentIndex >= totalCount - 1;

    return Column(
      children: [
        ProgressRow(current: currentIndex + 1, total: totalCount),
        const SizedBox(height: AppSizes.lg),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.colorScheme.surface,
                      theme.colorScheme.primary.withValues(alpha: 0.05),
                    ],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  character.character,
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    character.romaji,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TtsPlayButton(
                    text: character.character,
                    iconSize: 22,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                character.pronunciation,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              if (character.exampleWord != null) ...[
                const SizedBox(height: AppSizes.md),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh
                        .withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        character.exampleWord!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (character.exampleReading != null ||
                          character.exampleMeaning != null)
                        Text(
                          [
                            character.exampleReading,
                            character.exampleMeaning,
                          ].whereType<String>().join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: onNext,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLast ? '연습하기' : '다음',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  if (!isLast) ...[
                    const SizedBox(width: 4),
                    const Icon(LucideIcons.arrowRight, size: 16),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
