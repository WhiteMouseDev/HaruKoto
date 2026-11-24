import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/theme/text_theme.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(wordbookProvider.notifier).refresh());
    });
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
    final foreground = theme.brightness == Brightness.light
        ? AppColors.redesignForeground
        : theme.colorScheme.onSurface;
    final wordbook = ref.watch(wordbookProvider);
    final wordbookController = ref.read(wordbookProvider.notifier);
    final showListControls = wordbook.loading ||
        wordbook.entries.isNotEmpty ||
        wordbook.search.isNotEmpty ||
        wordbook.filter != 'ALL' ||
        wordbook.page > 1;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        titleSpacing: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: foreground,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(LucideIcons.arrowLeft, size: 20),
        ),
        title: const Text(
          '단어장',
          style: TextStyle(
            fontFamily: redesignFontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (showListControls)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: TextButton.icon(
                onPressed: _showAddDialog,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('추가'),
                style: TextButton.styleFrom(
                  foregroundColor: foreground,
                  minimumSize: const Size(48, kMinInteractiveDimension),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (showListControls) ...[
              const SizedBox(height: AppSizes.sm),
              WordbookSearchField(
                controller: _searchController,
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: AppSizes.xs),
              WordbookFilterChips(
                activeFilter: wordbook.filter,
                onFilterChanged: _changeFilter,
              ),
              const SizedBox(height: AppSizes.sm),
            ],
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
