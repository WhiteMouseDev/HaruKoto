import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/theme/text_theme.dart';
import '../../../../shared/widgets/pagination_footer.dart';
import '../../data/models/word_entry_model.dart';
import '../../providers/wrong_answers_provider.dart';
import 'study_list_status.dart';
import 'wrong_answer_card.dart';
import 'wrong_answers_overview.dart';
import 'wrong_answers_sort_menu.dart';

class WrongAnswersContent extends StatelessWidget {
  const WrongAnswersContent({
    super.key,
    required this.state,
    required this.onRetry,
    required this.onOpenStudy,
    required this.onStartReview,
    required this.onSortChanged,
    required this.onToggleExpand,
    required this.onSaveToWordbook,
    required this.onPagePrev,
    required this.onPageNext,
  });

  final WrongAnswersState state;
  final VoidCallback onRetry;
  final VoidCallback onOpenStudy;
  final ValueChanged<WrongAnswersSummary> onStartReview;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<String> onToggleExpand;
  final Future<void> Function(WrongEntryModel) onSaveToWordbook;
  final VoidCallback onPagePrev;
  final VoidCallback onPageNext;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final light = colors.brightness == Brightness.light;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;
    final border = light ? AppColors.redesignOutline : colors.outlineVariant;
    final summary = state.summary;

    if (state.error != null && !state.loading) {
      return StudyListStatus(
        icon: const Icon(LucideIcons.barChart3, size: 32),
        title: '오답노트를 불러올 수 없습니다.',
        subtitle: '네트워크 연결을 확인해 주세요.',
        action: StudyListStatusAction(
          label: '다시 시도하기',
          icon: LucideIcons.rotateCcw,
          onPressed: onRetry,
        ),
      );
    }

    if (!state.loading && state.entries.isEmpty && state.page == 1) {
      return StudyListStatus(
        icon: const Icon(LucideIcons.inbox, size: 32),
        title: '오답노트 내역이 없어요.',
        subtitle: '학습을 시작해 보세요!',
        action: StudyListStatusAction(
          label: '학습 시작',
          icon: LucideIcons.play,
          onPressed: onOpenStudy,
        ),
      );
    }

    return CustomScrollView(
      key: ValueKey((state.sort, state.page)),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pageHorizontal,
            AppSizes.sm,
            AppSizes.pageHorizontal,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WrongAnswersOverview(
                  summary: summary,
                  onStartReview:
                      summary != null && !state.loading && summary.remaining > 0
                          ? () => onStartReview(summary)
                          : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        summary == null ? '오답 목록' : '${summary.totalWrong}개',
                        style: TextStyle(
                          fontFamily: redesignFontFamily,
                          fontSize: 13,
                          color: foreground,
                        ),
                      ),
                    ),
                    WrongAnswersSortMenu(
                      activeSort: state.sort,
                      onSortChanged: onSortChanged,
                    ),
                  ],
                ),
                const Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _StatusIndicator('학습 중', AppColors.redesignGrammar),
                    _StatusIndicator('학습 완료', AppColors.redesignSentence),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.pageHorizontal,
          ),
          sliver: state.loading
              ? SliverToBoxAdapter(
                  child: Semantics(
                    label: '오답 목록을 불러오는 중',
                    liveRegion: true,
                    child: Column(
                      children: List.generate(
                          4,
                          (_) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  height: 60 *
                                      MediaQuery.textScalerOf(context).scale(1),
                                  decoration: BoxDecoration(
                                    color: light
                                        ? AppColors.redesignSurface
                                        : colors.surfaceContainerHigh,
                                    border: Border.all(color: border),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              )),
                    ),
                  ),
                )
              : SliverList.builder(
                  itemCount: state.entries.length,
                  itemBuilder: (context, index) {
                    final entry = state.entries[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: WrongAnswerCard(
                        key: ValueKey(entry.id),
                        entry: entry,
                        expanded: state.expandedId == entry.id,
                        saved: state.savedWords.contains(entry.vocabularyId),
                        onTap: () => onToggleExpand(entry.id),
                        onSaveToWordbook: () => onSaveToWordbook(entry),
                      ),
                    );
                  },
                ),
        ),
        if (!state.loading)
          SliverToBoxAdapter(
            child: PaginationFooter(
              page: state.page,
              totalPages: state.totalPages,
              onPagePrev: onPagePrev,
              onPageNext: onPageNext,
            ),
          ),
      ],
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const SizedBox.square(dimension: 6),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: redesignFontFamily,
            fontSize: 11,
            color: colors.brightness == Brightness.light
                ? AppColors.redesignMutedForeground
                : colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
