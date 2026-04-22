import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/sizes.dart';
import '../providers/learned_words_provider.dart';
import 'widgets/learned_words_content.dart';
import 'widgets/learned_words_filter_chips.dart';
import 'widgets/learned_words_overview.dart';
import 'widgets/learned_words_search_field.dart';
import 'widgets/learned_words_sort_tabs.dart';

class LearnedWordsPage extends ConsumerStatefulWidget {
  const LearnedWordsPage({super.key});

  @override
  ConsumerState<LearnedWordsPage> createState() => _LearnedWordsPageState();
}

class _LearnedWordsPageState extends ConsumerState<LearnedWordsPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(learnedWordsProvider.notifier).refresh());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(ref.read(learnedWordsProvider.notifier).changeSearch(value));
    });
  }

  static const _sortOptions = [
    ('recent', '최신순'),
    ('alphabetical', '가나다순'),
    ('most-studied', '많이 푼 순'),
  ];

  void _changeSort(String sort) {
    unawaited(ref.read(learnedWordsProvider.notifier).changeSort(sort));
  }

  void _changeFilter(String filter) {
    unawaited(ref.read(learnedWordsProvider.notifier).changeFilter(filter));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final learnedWords = ref.watch(learnedWordsProvider);
    final learnedWordsController = ref.read(learnedWordsProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSizes.pageHorizontal,
                  AppSizes.md, AppSizes.pageHorizontal, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(LucideIcons.arrowLeft, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '내가 학습한 단어',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (learnedWords.summary != null)
              LearnedWordsOverview(summary: learnedWords.summary!),
            const SizedBox(height: 12),
            LearnedWordsSearchField(
              controller: _searchController,
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LearnedWordsSortTabs(
                sortOptions: _sortOptions,
                activeSort: learnedWords.sort,
                onSortChanged: _changeSort,
              ),
            ),
            const SizedBox(height: 8),
            LearnedWordsFilterChips(
              activeFilter: learnedWords.filter,
              onFilterChanged: _changeFilter,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: LearnedWordsContent(
                loading: learnedWords.loading,
                error: learnedWords.error,
                entries: learnedWords.entries,
                totalPages: learnedWords.totalPages,
                page: learnedWords.page,
                search: learnedWords.search,
                filter: learnedWords.filter,
                expandedId: learnedWords.expandedId,
                onRetry: learnedWordsController.refresh,
                onToggleExpand: learnedWordsController.toggleExpanded,
                onPagePrev: learnedWordsController.previousPage,
                onPageNext: learnedWordsController.nextPage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
