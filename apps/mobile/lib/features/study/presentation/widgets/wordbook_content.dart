import 'package:flutter/material.dart';

import '../../../../shared/widgets/app_error_retry.dart';
import '../../data/models/wordbook_entry_model.dart';
import 'wordbook_empty_state.dart';
import 'wordbook_list.dart';
import 'wordbook_loading_list.dart';

class WordbookContent extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<WordbookEntryModel> entries;
  final int totalPages;
  final int page;
  final String search;
  final String filter;
  final VoidCallback onRetry;
  final VoidCallback onAddFirst;
  final ValueChanged<String> onDelete;
  final VoidCallback onPagePrev;
  final VoidCallback onPageNext;

  const WordbookContent({
    super.key,
    required this.loading,
    required this.error,
    required this.entries,
    required this.totalPages,
    required this.page,
    required this.search,
    required this.filter,
    required this.onRetry,
    required this.onAddFirst,
    required this.onDelete,
    required this.onPagePrev,
    required this.onPageNext,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const WordbookLoadingList();
    }

    if (error != null) {
      return AppErrorRetry(
        onRetry: onRetry,
        message: error,
      );
    }

    if (entries.isEmpty) {
      return WordbookEmptyState(
        hasActiveQuery: search.isNotEmpty || filter != 'ALL',
        onAddFirst: onAddFirst,
      );
    }

    return WordbookList(
      entries: entries,
      totalPages: totalPages,
      page: page,
      onDelete: onDelete,
      onPagePrev: onPagePrev,
      onPageNext: onPageNext,
    );
  }
}
