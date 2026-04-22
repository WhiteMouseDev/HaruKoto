import 'package:flutter/material.dart';

import '../../../../shared/widgets/tts_play_button.dart';
import '../../data/models/wordbook_entry_model.dart';

class WordbookEntryCardContent extends StatelessWidget {
  final WordbookEntryModel entry;

  const WordbookEntryCardContent({
    super.key,
    required this.entry,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _WordbookEntryText(entry: entry)),
        WordbookEntrySourceBadge(source: entry.source),
      ],
    );
  }
}

class _WordbookEntryText extends StatelessWidget {
  final WordbookEntryModel entry;

  const _WordbookEntryText({required this.entry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              entry.word,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            TtsPlayButton(
              vocabId: entry.id,
              iconSize: 16,
            ),
            const SizedBox(width: 8),
            Text(
              entry.reading,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          entry.meaningKo,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class WordbookEntrySourceBadge extends StatelessWidget {
  final String source;

  const WordbookEntrySourceBadge({
    super.key,
    required this.source,
  });

  String get label {
    switch (source) {
      case 'QUIZ':
        return '퀴즈';
      case 'CONVERSATION':
        return '회화';
      default:
        return '직접 추가';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 10,
        ),
      ),
    );
  }
}
