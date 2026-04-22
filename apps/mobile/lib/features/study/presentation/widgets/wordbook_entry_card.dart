import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../data/models/wordbook_entry_model.dart';
import 'wordbook_entry_card_content.dart';

class WordbookEntryCard extends StatelessWidget {
  final WordbookEntryModel entry;
  final VoidCallback onDelete;

  const WordbookEntryCard({
    super.key,
    required this.entry,
    required this.onDelete,
  });

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
          color: AppColors.error(theme.brightness),
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
        child: WordbookEntryCardContent(entry: entry),
      ),
    );
  }
}
