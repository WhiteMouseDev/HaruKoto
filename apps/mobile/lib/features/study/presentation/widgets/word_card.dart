import 'package:flutter/material.dart';

import '../../data/models/word_entry_model.dart';
import 'learned_word_card_detail.dart';
import 'learned_word_card_header.dart';

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
              LearnedWordCardHeader(word: word),
              if (expanded) LearnedWordCardDetail(word: word),
            ],
          ),
        ),
      ),
    );
  }
}
