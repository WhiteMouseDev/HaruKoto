import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../shared/widgets/tts_play_button.dart';
import '../../data/models/wordbook_entry_model.dart';

class WordbookEntryCard extends StatelessWidget {
  final WordbookEntryModel entry;
  final VoidCallback onDelete;

  const WordbookEntryCard({
    super.key,
    required this.entry,
    required this.onDelete,
  });

  String get _sourceLabel {
    switch (entry.source) {
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

    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error(Theme.of(context).brightness),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(LucideIcons.trash2,
            color: AppColors.onGradient, size: 20),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
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
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
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
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _sourceLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
