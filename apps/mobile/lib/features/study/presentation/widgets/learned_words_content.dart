import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_error_retry.dart';
import '../../data/models/word_entry_model.dart';
import 'learned_words_empty_state.dart';
import 'learned_words_list.dart';
import 'learned_words_loading_list.dart';

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
    if (loading) {
      return const LearnedWordsLoadingList();
    }

    if (error != null) {
      return AppErrorRetry(
        onRetry: onRetry,
        message: error,
      );
    }

    if (entries.isEmpty) {
      return LearnedWordsEmptyState(
        hasActiveQuery: search.isNotEmpty || filter != 'ALL',
      );
    }

    return LearnedWordsList(
      entries: entries,
      totalPages: totalPages,
      page: page,
      expandedId: expandedId,
      onToggleExpand: onToggleExpand,
      onPagePrev: onPagePrev,
      onPageNext: onPageNext,
    );
  }
}
