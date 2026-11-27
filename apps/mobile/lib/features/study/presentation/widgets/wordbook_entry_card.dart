import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/wordbook_entry_model.dart';
import 'wordbook_entry_card_content.dart';

class WordbookEntryCard extends StatelessWidget {
  final WordbookEntryModel entry;
  final VoidCallback onOpen;
  final Future<void> Function() onDelete;
  final Widget? detail;

  const WordbookEntryCard({
    super.key,
    required this.entry,
    required this.onOpen,
    required this.onDelete,
    this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(12);
    final borderColor = theme.brightness == Brightness.light
        ? AppColors.redesignOutline
        : theme.colorScheme.outline;

    return Dismissible(
      key: Key(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error(theme.brightness),
          borderRadius: borderRadius,
        ),
        child: const Icon(LucideIcons.trash2,
            color: AppColors.onGradient, size: 20),
      ),
      confirmDismiss: (_) async {
        await onDelete();
        // The list owns removal after a successful API response.
        return false;
      },
      child: Material(
        type: MaterialType.transparency,
        clipBehavior: Clip.antiAlias,
        borderRadius: borderRadius,
        child: Ink(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: borderColor),
            borderRadius: borderRadius,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                button: true,
                expanded: detail != null,
                child: InkWell(
                  onTap: onOpen,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.md, vertical: 12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 52),
                      child: WordbookEntryCardContent(
                        entry: entry,
                        expanded: detail != null,
                      ),
                    ),
                  ),
                ),
              ),
              if (detail case final content?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSizes.md, 0, AppSizes.md, AppSizes.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Divider(height: 1, color: borderColor),
                      const SizedBox(height: AppSizes.sm),
                      content,
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
