import 'package:flutter/material.dart';

import '../../../../shared/widgets/pagination_footer.dart';
import '../../data/models/word_entry_model.dart';
import 'word_card.dart';

class LearnedWordsList extends StatelessWidget {
  final List<LearnedWordModel> entries;
  final int totalPages;
  final int page;
  final String? expandedId;
  final ValueChanged<String> onToggleExpand;
  final VoidCallback onPagePrev;
  final VoidCallback onPageNext;

  const LearnedWordsList({
    super.key,
    required this.entries,
    required this.totalPages,
    required this.page,
    required this.expandedId,
    required this.onToggleExpand,
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
                child: WordCard(
                  word: entry,
                  expanded: expandedId == entry.id,
                  onTap: () => onToggleExpand(entry.id),
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
