import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../shared/widgets/app_error_retry.dart';
import '../../../../shared/widgets/pagination_footer.dart';
import '../../data/models/word_entry_model.dart';
import 'wrong_answer_card.dart';

class WrongAnswersContent extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<WrongEntryModel> entries;
  final int totalPages;
  final int page;
  final String? expandedId;
  final Set<String> savedWords;
  final VoidCallback onRetry;
  final ValueChanged<String> onToggleExpand;
  final ValueChanged<WrongEntryModel> onSaveToWordbook;
  final VoidCallback onPagePrev;
  final VoidCallback onPageNext;

  const WrongAnswersContent({
    super.key,
    required this.loading,
    required this.error,
    required this.entries,
    required this.totalPages,
    required this.page,
    required this.expandedId,
    required this.savedWords,
    required this.onRetry,
    required this.onToggleExpand,
    required this.onSaveToWordbook,
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
              height: 72,
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
            Icon(LucideIcons.partyPopper,
                size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              '틀린 단어가 없어요! 완벽해요!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('학습으로 돌아가기'),
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
                child: WrongAnswerCard(
                  entry: entry,
                  expanded: expandedId == entry.id,
                  saved: savedWords.contains(entry.vocabularyId),
                  onTap: () => onToggleExpand(entry.id),
                  onSaveToWordbook: () => onSaveToWordbook(entry),
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
