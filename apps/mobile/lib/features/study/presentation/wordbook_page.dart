import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/auth/current_account_provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/haru_typography.dart';
import '../../../core/theme/text_theme.dart';
import '../../../shared/widgets/haru_button_styles.dart';
import '../providers/study_provider.dart';
import '../providers/wordbook_provider.dart';
import 'widgets/study_list_sort_menu.dart';
import 'widgets/wordbook_content.dart';
import 'widgets/wordbook_entry_detail.dart';
import 'widgets/wordbook_entry_dialog.dart';
import 'widgets/wordbook_filter_chips.dart';
import 'widgets/wordbook_search_field.dart';

const _wordbookSortOptions = [
  ('recent', '최근 추가순'),
  ('most-wrong', '많이 틀린 순'),
];

class WordbookPage extends ConsumerStatefulWidget {
  const WordbookPage({super.key});

  @override
  ConsumerState<WordbookPage> createState() => _WordbookPageState();
}

class _WordbookPageState extends ConsumerState<WordbookPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _openingAddForm = false;
  String? _expandedEntryId;
  String? _expandedOwner;

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
    _collapseEntry();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(ref.read(wordbookProvider.notifier).changeSearch(value));
    });
  }

  Future<void> _deleteWord(String id) async {
    final deleted = await ref.read(wordbookProvider.notifier).deleteWord(id);
    if (!mounted) return;
    if (deleted && _expandedEntryId == id) _collapseEntry();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(deleted ? '삭제되었습니다' : '삭제에 실패했습니다')),
    );
  }

  bool _isCurrent(String owner) =>
      mounted && ref.read(currentAccountReaderProvider)() == owner;

  void _refreshList(String owner) {
    if (_isCurrent(owner)) {
      unawaited(ref.read(wordbookProvider.notifier).refresh());
    }
  }

  Future<void> _showAddDialog() async {
    if (_openingAddForm) return;
    final owner = ref.read(currentAccountReaderProvider)();
    if (owner == null) return;
    _openingAddForm = true;
    try {
      final saved = await showWordbookEntryDialog(
        context,
        onSave: (fields) async {
          if (!_isCurrent(owner)) {
            throw const ApiException(message: '계정이 변경되었어요.');
          }
          await ref.read(studyRepositoryProvider).addWord(
                word: fields.word,
                reading: fields.reading,
                meaningKo: fields.meaningKo,
                preserveExisting: true,
              );
        },
      );
      if (saved) _refreshList(owner);
    } finally {
      _openingAddForm = false;
    }
  }

  void _toggleEntry(String id) {
    if (_expandedEntryId == id) {
      _collapseEntry();
      return;
    }
    final owner = ref.read(currentAccountReaderProvider)();
    if (owner == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _expandedEntryId = id;
      _expandedOwner = owner;
    });
  }

  void _collapseEntry() {
    if (_expandedEntryId == null) return;
    setState(() {
      _expandedEntryId = null;
      _expandedOwner = null;
    });
  }

  Widget _buildDetail(String id) {
    final owner = _expandedOwner;
    if (owner == null) return const SizedBox.shrink();
    return WordbookEntryDetail(
      key: ValueKey(id),
      entryId: id,
      owner: owner,
      onUpdated: () => _refreshList(owner),
      onDeleted: () {
        if (!_isCurrent(owner)) return;
        if (_expandedEntryId == id) _collapseEntry();
        _refreshList(owner);
      },
    );
  }

  void _changeFilter(String filter) {
    _collapseEntry();
    unawaited(ref.read(wordbookProvider.notifier).changeFilter(filter));
  }

  void _changeSort(String sort) {
    if (ref.read(wordbookProvider).sort == sort) return;
    _debounce?.cancel();
    _collapseEntry();
    unawaited(ref.read(wordbookProvider.notifier).changeSort(
          sort,
          search: _searchController.text,
        ));
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
              padding: const EdgeInsetsDirectional.only(
                  end: AppSizes.pageHorizontal),
              child: TextButton.icon(
                onPressed: _showAddDialog,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('추가'),
                style: HaruButtonStyles.pillTab(
                  context,
                  selected: true,
                  minimumWidth: 84,
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
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: WordbookFilterChips(
                  activeFilter: wordbook.filter,
                  onFilterChanged: _changeFilter,
                ),
              ),
              Padding(
                padding: AppSizes.pageHorizontalEdge,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        wordbook.loading || wordbook.error != null
                            ? '단어 목록'
                            : '${wordbook.total}개',
                        style:
                            HaruTypography.krBody3.copyWith(color: foreground),
                      ),
                    ),
                    StudyListSortMenu(
                      options: _wordbookSortOptions,
                      activeSort: wordbook.sort,
                      onSortChanged: _changeSort,
                    ),
                  ],
                ),
              ),
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
                expandedEntryId: _expandedEntryId,
                onOpen: _toggleEntry,
                buildDetail: _buildDetail,
                onDelete: _deleteWord,
                onPagePrev: () {
                  _collapseEntry();
                  unawaited(wordbookController.previousPage());
                },
                onPageNext: () {
                  _collapseEntry();
                  unawaited(wordbookController.nextPage());
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
