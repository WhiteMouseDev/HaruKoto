import 'package:flutter/material.dart';

import '../../../../core/constants/sizes.dart';
import '../../../../shared/widgets/pagination_footer.dart';
import '../../data/models/wordbook_entry_model.dart';
import 'wordbook_entry_card.dart';

class WordbookList extends StatelessWidget {
  final List<WordbookEntryModel> entries;
  final int totalPages;
  final int page;
  final String? expandedEntryId;
  final ValueChanged<String> onOpen;
  final Widget Function(String id) buildDetail;
  final Future<void> Function(String) onDelete;
  final VoidCallback onPagePrev;
  final VoidCallback onPageNext;

  const WordbookList({
    super.key,
    required this.entries,
    required this.totalPages,
    required this.page,
    required this.expandedEntryId,
    required this.onOpen,
    required this.buildDetail,
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
            padding: AppSizes.pageHorizontalEdge,
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];

              return Padding(
                key: ValueKey(entry.id),
                padding: const EdgeInsets.only(bottom: 8),
                child: WordbookEntryCard(
                  entry: entry,
                  onOpen: () => onOpen(entry.id),
                  onDelete: () => onDelete(entry.id),
                  detail: expandedEntryId == entry.id
                      ? buildDetail(entry.id)
                      : null,
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
