import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../shared/widgets/app_error_retry.dart';
import '../../../../shared/widgets/pagination_footer.dart';
import '../../data/models/word_entry_model.dart';
import 'wrong_answers_mini_stat.dart';

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
                color: theme.colorScheme.onSurface
                    .withValues(alpha: 0.5),
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
              final isExpanded = expandedId == entry.id;
              final total =
                  entry.correctCount + entry.incorrectCount;
              final accuracy = total > 0
                  ? (entry.correctCount * 100 ~/ total)
                  : 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onToggleExpand(entry.id),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: theme.colorScheme.outline),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildHeader(
                              theme, entry, isExpanded),
                          if (isExpanded)
                            _buildExpandedDetail(
                                theme, entry, accuracy, total),
                        ],
                      ),
                    ),
                  ),
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

  Widget _buildHeader(
    ThemeData theme,
    WrongEntryModel entry,
    bool isExpanded,
  ) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.error(theme.brightness)
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '${entry.incorrectCount}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.error(theme.brightness),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    entry.word,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
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
              Text(
                entry.meaningKo,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface
                      .withValues(alpha: 0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: entry.mastered
                ? theme.colorScheme.primary
                    .withValues(alpha: 0.1)
                : AppColors.error(theme.brightness)
                    .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            entry.mastered ? '극복' : '학습중',
            style: theme.textTheme.labelSmall?.copyWith(
              color: entry.mastered
                  ? theme.colorScheme.primary
                  : AppColors.error(theme.brightness),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 4),
        AnimatedRotation(
          turns: isExpanded ? 0.5 : 0,
          duration: const Duration(milliseconds: 200),
          child: Icon(
            LucideIcons.chevronDown,
            size: 16,
            color: theme.colorScheme.onSurface
                .withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedDetail(
    ThemeData theme,
    WrongEntryModel entry,
    int accuracy,
    int total,
  ) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Divider(color: theme.colorScheme.outline, height: 1),
        const SizedBox(height: 12),
        Row(
          children: [
            WrongAnswersMiniStat(
                label: '오답',
                value: '${entry.incorrectCount}회',
                isError: true),
            const SizedBox(width: 8),
            WrongAnswersMiniStat(
                label: '정답률', value: '$accuracy%'),
            const SizedBox(width: 8),
            WrongAnswersMiniStat(
                label: '총 풀이', value: '$total회'),
          ],
        ),
        if (entry.exampleSentence != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.exampleSentence!,
                    style: theme.textTheme.bodySmall),
                if (entry.exampleTranslation != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    entry.exampleTranslation!,
                    style:
                        theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(
                    color: theme.colorScheme.outline),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(entry.jlptLevel,
                  style: theme.textTheme.labelSmall),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => onSaveToWordbook(entry),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color:
                      savedWords.contains(entry.vocabularyId)
                          ? theme.colorScheme.primary
                              .withValues(alpha: 0.1)
                          : theme.colorScheme
                              .surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      savedWords
                              .contains(entry.vocabularyId)
                          ? LucideIcons.check
                          : LucideIcons.bookmarkPlus,
                      size: 12,
                      color: savedWords
                              .contains(entry.vocabularyId)
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      savedWords
                              .contains(entry.vocabularyId)
                          ? '저장됨'
                          : '단어장에 추가',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
