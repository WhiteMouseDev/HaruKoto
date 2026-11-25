import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/theme/text_theme.dart';
import '../../../../shared/widgets/pagination_footer.dart';
import '../../data/models/word_entry_model.dart';
import '../../providers/wrong_answers_provider.dart';
import 'study_list_status.dart';
import 'wordbook_search_field.dart';
import 'wrong_answer_card.dart';
import 'wrong_answers_overview.dart';
import 'wrong_answers_sort_menu.dart';

class WrongAnswersContent extends StatelessWidget {
  const WrongAnswersContent({
    super.key,
    required this.state,
    required this.searchController,
    required this.scrollController,
    required this.onRetry,
    required this.onOpenStudy,
    required this.onStartReview,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onClearFilters,
    required this.onSortChanged,
    required this.onToggleExpand,
    required this.onSaveToWordbook,
    required this.onPagePrev,
    required this.onPageNext,
  });

  final WrongAnswersState state;
  final TextEditingController searchController;
  final ScrollController scrollController;
  final VoidCallback onRetry;
  final VoidCallback onOpenStudy;
  final ValueChanged<WrongAnswersSummary> onStartReview;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<WrongAnswerStatus> onStatusChanged;
  final VoidCallback onClearFilters;
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
    final showFilters =
        state.supportsSearchAndStatus && (summary?.totalWrong ?? 0) > 0;
    final failed = state.error != null && !state.loading;
    final empty = !state.loading && !failed && state.entries.isEmpty;
    final errorStatus = StudyListStatus(
      icon: const Icon(LucideIcons.barChart3, size: 32),
      title: '오답노트를 불러올 수 없습니다.',
      subtitle: '네트워크 연결을 확인해 주세요.',
      action: StudyListStatusAction(
        label: '다시 시도하기',
        icon: LucideIcons.rotateCcw,
        onPressed: onRetry,
      ),
    );

    if (failed && !showFilters) return errorStatus;

    if (empty && state.page == 1 && !state.hasActiveFilters) {
      return StudyListStatus(
        icon: SvgPicture.asset(
          'assets/icons/figma-wrong-answers-empty.svg',
          width: 40,
          height: 40,
          colorFilter: light
              ? null
              : ColorFilter.mode(colors.onSurfaceVariant, BlendMode.srcIn),
        ),
        title: '오답노트 내역이 없어요.',
        subtitle: '학습을 시작해 보세요!',
        action: StudyListStatusAction(
          label: '학습 시작',
          onPressed: onOpenStudy,
        ),
      );
    }

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pageHorizontal,
            0,
            AppSizes.pageHorizontal,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WrongAnswersOverview(
                  summary: summary,
                  onStartReview: summary != null && summary.remaining > 0
                      ? () => onStartReview(summary)
                      : null,
                ),
                if (showFilters) ...[
                  const SizedBox(height: 37),
                  WordbookSearchField.wrongAnswers(
                    controller: searchController,
                    onChanged: onSearchChanged,
                  ),
                  const SizedBox(height: 8),
                  _StatusChips(
                    selectedStatus: state.status,
                    onChanged: onStatusChanged,
                  ),
                ] else
                  const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        state.loading || failed ? '오답 목록' : '${state.total}개',
                        style: TextStyle(
                          fontFamily: redesignFontFamily,
                          fontSize: 13,
                          height: 1.5,
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
                if (!failed && !empty) const _WrongAnswersLegend(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        if (failed)
          SliverToBoxAdapter(child: errorStatus)
        else if (empty && state.hasActiveFilters)
          SliverToBoxAdapter(
            child: StudyListStatus(
              icon: const Icon(LucideIcons.search, size: 28),
              title: '조건에 맞는 오답이 없어요.',
              action: StudyListStatusAction(
                label: '검색·필터 초기화',
                icon: LucideIcons.rotateCcw,
                onPressed: onClearFilters,
              ),
            ),
          )
        else
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
                                    height: 79 *
                                        MediaQuery.textScalerOf(context)
                                            .scale(1),
                                    decoration: BoxDecoration(
                                      color: light
                                          ? AppColors.redesignSurface
                                          : colors.surfaceContainerHigh,
                                      border: Border.all(color: border),
                                      borderRadius: BorderRadius.circular(12),
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
        if (!state.loading && !failed)
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

class _StatusChips extends StatelessWidget {
  const _StatusChips({
    required this.selectedStatus,
    required this.onChanged,
  });

  final WrongAnswerStatus selectedStatus;
  final ValueChanged<WrongAnswerStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final light = colors.brightness == Brightness.light;
    final selectedSurface =
        light ? AppColors.redesignStrong : colors.primaryContainer;
    final selectedLabel = light ? Colors.white : colors.onPrimaryContainer;
    final unselectedSurface =
        light ? AppColors.redesignControl : colors.surfaceContainerHigh;
    final unselectedLabel =
        light ? AppColors.redesignForeground : colors.onSurfaceVariant;

    return Wrap(
      spacing: 4,
      children: [
        for (final (status, label) in const [
          (WrongAnswerStatus.all, '전체'),
          (WrongAnswerStatus.learning, '학습중'),
          (WrongAnswerStatus.mastered, '학습 완료'),
        ])
          ChoiceChip(
            label: Text(label),
            selected: selectedStatus == status,
            onSelected: (selected) {
              if (selected) onChanged(status);
            },
            showCheckmark: false,
            shape: const StadiumBorder(),
            side: BorderSide.none,
            backgroundColor: unselectedSurface,
            selectedColor: selectedSurface,
            padding: EdgeInsets.zero,
            labelPadding: const EdgeInsets.symmetric(horizontal: 20),
            visualDensity: VisualDensity.standard,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            labelStyle: TextStyle(
              fontFamily: redesignFontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
              color: selectedStatus == status ? selectedLabel : unselectedLabel,
            ),
          ),
      ],
    );
  }
}

class _WrongAnswersLegend extends StatelessWidget {
  const _WrongAnswersLegend();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.brightness == Brightness.light
            ? AppColors.redesignControl
            : colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            const Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _StatusIndicator('학습중', AppColors.redesignGrammar),
                  _StatusIndicator('학습완료', AppColors.redesignSentence),
                ],
              ),
            ),
            _StatusIndicator(
              '틀린 횟수',
              colors.brightness == Brightness.light
                  ? const Color(0xFFD32F2F)
                  : colors.error,
              round: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator(this.label, this.color, {this.round = false});

  final String label;
  final Color color;
  final bool round;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(round ? 5 : 2),
          ),
          child: const SizedBox.square(dimension: 10),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: redesignFontFamily,
            fontSize: 11,
            height: 1.5,
            color: colors.brightness == Brightness.light
                ? AppColors.redesignForeground
                : colors.onSurface,
          ),
        ),
      ],
    );
  }
}
