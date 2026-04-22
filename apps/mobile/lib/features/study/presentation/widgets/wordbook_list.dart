import 'package:flutter/material.dart';

import '../../../../shared/widgets/pagination_footer.dart';
import '../../data/models/wordbook_entry_model.dart';
import 'wordbook_entry_card.dart';

class WordbookList extends StatelessWidget {
  final List<WordbookEntryModel> entries;
  final int totalPages;
  final int page;
  final ValueChanged<String> onDelete;
  final VoidCallback onPagePrev;
  final VoidCallback onPageNext;

  const WordbookList({
    super.key,
    required this.entries,
    required this.totalPages,
    required this.page,
    required this.onDelete,
    required this.onPagePrev,
    required this.onPageNext,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: WordbookEntryCard(
                  entry: entry,
                  onDelete: () => onDelete(entry.id),
                ),
              );
            },
          ),
        ),
        PaginationFooter(
          page: page,
          totalPages: totalPages,
          onPagePrev: onPagePrev,
          onPageNext: onPageNext,
        ),
      ],
    );
  }
}
