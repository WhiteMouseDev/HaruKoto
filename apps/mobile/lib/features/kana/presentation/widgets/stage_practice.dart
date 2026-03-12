import 'package:flutter/material.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/kana_character_model.dart';
import 'kana_flashcard.dart';
import 'progress_row.dart';

class StagePractice extends StatelessWidget {
  final KanaCharacterModel character;
  final int currentIndex;
  final int totalCount;
  final VoidCallback onKnow;
  final VoidCallback onDontKnow;

  const StagePractice({
    super.key,
    required this.character,
    required this.currentIndex,
    required this.totalCount,
    required this.onKnow,
    required this.onDontKnow,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ProgressRow(current: currentIndex + 1, total: totalCount),
        const SizedBox(height: AppSizes.lg),
        Expanded(
          child: Center(
            child: KanaFlashcard(
              key: ValueKey('practice-$currentIndex'),
              character: character.character,
              romaji: character.romaji,
              pronunciation: character.pronunciation,
              exampleWord: character.exampleWord,
              exampleReading: character.exampleReading,
              exampleMeaning: character.exampleMeaning,
              onKnow: onKnow,
              onDontKnow: onDontKnow,
            ),
          ),
        ),
      ],
    );
  }
}
