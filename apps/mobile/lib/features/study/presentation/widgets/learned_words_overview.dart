import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../data/models/word_entry_model.dart';
import 'learned_words_summary_tile.dart';

class LearnedWordsOverview extends StatelessWidget {
  final LearnedWordsSummary summary;

  const LearnedWordsOverview({
    super.key,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          LearnedWordsSummaryTile(
            label: '전체',
            value: '${summary.totalLearned}',
          ),
          const SizedBox(width: 8),
          LearnedWordsSummaryTile(
            label: '마스터',
            value: '${summary.mastered}',
            valueColor: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          LearnedWordsSummaryTile(
            label: '학습중',
            value: '${summary.learning}',
            valueColor: AppColors.info(theme.brightness),
          ),
        ],
      ),
    );
  }
}
