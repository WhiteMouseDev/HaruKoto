import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../shared/widgets/app_error_retry.dart';
import '../../../../shared/widgets/pagination_footer.dart';
import '../../data/models/word_entry_model.dart';
import 'word_card.dart';

class LearnedWordsContent extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<LearnedWordModel> entries;
  final int totalPages;
  final int page;
  final String search;
  final String filter;
  final String? expandedId;
  final VoidCallback onRetry;
  final ValueChanged<String> onToggleExpand;
  final VoidCallback onPagePrev;
  final VoidCallback onPageNext;

  const LearnedWordsContent({
    super.key,
    required this.loading,
    required this.error,
    required this.entries,
    required this.totalPages,
    required this.page,
    required this.search,
    required this.filter,
    required this.expandedId,
    required this.onRetry,
    required this.onToggleExpand,
    required this.onPagePrev,
    required this.onPageNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (loading) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: List.generate(
          5,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      );
    }

    if (error != null) {
      return AppErrorRetry(
        onRetry: onRetry,
        message: error,
      );
    }

    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.bookOpen,
                size: 48,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              search.isNotEmpty || filter != 'ALL'
                  ? '검색 결과가 없어요'
                  : '아직 학습한 단어가 없어요',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

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
