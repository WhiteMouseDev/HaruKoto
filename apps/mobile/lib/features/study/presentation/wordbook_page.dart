import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/sizes.dart';
import '../providers/wordbook_provider.dart';
import 'widgets/add_word_dialog.dart';
import 'widgets/wordbook_content.dart';
import 'widgets/wordbook_filter_chips.dart';
import 'widgets/wordbook_search_field.dart';

class WordbookPage extends ConsumerStatefulWidget {
  const WordbookPage({super.key});

  @override
  ConsumerState<WordbookPage> createState() => _WordbookPageState();
}

class _WordbookPageState extends ConsumerState<WordbookPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(wordbookProvider.notifier).refresh());
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
      unawaited(ref.read(wordbookProvider.notifier).changeSearch(value));
    });
  }

  Future<void> _deleteWord(String id) async {
    final deleted = await ref.read(wordbookProvider.notifier).deleteWord(id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(deleted ? '삭제되었습니다' : '삭제에 실패했습니다')),
    );
  }

  void _showAddDialog() {
    showAddWordDialog(
      context,
      ref,
      onAdded: () {
        unawaited(ref.read(wordbookProvider.notifier).refresh());
      },
    );
  }

  void _changeFilter(String filter) {
    unawaited(ref.read(wordbookProvider.notifier).changeFilter(filter));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wordbook = ref.watch(wordbookProvider);
    final wordbookController = ref.read(wordbookProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
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
                  Expanded(
                    child: Text(
                      '내 단어장',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _showAddDialog,
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('추가'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 36),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            WordbookSearchField(
              controller: _searchController,
              onChanged: _onSearchChanged,
            ),
            const SizedBox(height: 8),
            WordbookFilterChips(
              activeFilter: wordbook.filter,
              onFilterChanged: _changeFilter,
            ),
            const SizedBox(height: 12),

            Expanded(
              child: WordbookContent(
                loading: wordbook.loading,
                error: wordbook.error,
                entries: wordbook.entries,
                totalPages: wordbook.totalPages,
                page: wordbook.page,
                search: wordbook.search,
                filter: wordbook.filter,
                onRetry: wordbookController.refresh,
                onAddFirst: _showAddDialog,
                onDelete: _deleteWord,
                onPagePrev: wordbookController.previousPage,
                onPageNext: wordbookController.nextPage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
