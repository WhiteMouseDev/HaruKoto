import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/sizes.dart';
import '../data/models/word_entry_model.dart';
import '../providers/study_provider.dart';
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
  String _search = '';
  String _sort = 'recent';
  String _filter = 'ALL';
  int _page = 1;

  List<LearnedWordModel> _entries = [];
  LearnedWordsSummary? _summary;
  int _totalPages = 1;
  bool _loading = true;
  String? _error;
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _fetchData();
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
      setState(() {
        _search = value;
        _page = 1;
      });
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = ref.read(studyRepositoryProvider);
    try {
      final data = await repo.fetchLearnedWords(
        page: _page,
        sort: _sort,
        search: _search,
        filter: _filter,
      );
      if (!mounted) return;
      setState(() {
        _entries = data.entries;
        _summary = data.summary;
        _totalPages = data.totalPages;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '데이터를 불러올 수 없습니다.';
        _loading = false;
      });
    }
  }

  static const _sortOptions = [
    ('recent', '최신순'),
    ('alphabetical', '가나다순'),
    ('most-studied', '많이 푼 순'),
  ];

  void _changeSort(String sort) {
    if (_sort == sort) return;
    setState(() {
      _sort = sort;
      _page = 1;
    });
    _fetchData();
  }

  void _changeFilter(String filter) {
    if (_filter == filter) return;
    setState(() {
      _filter = filter;
      _page = 1;
    });
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            if (_summary != null) LearnedWordsOverview(summary: _summary!),
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
                activeSort: _sort,
                onSortChanged: _changeSort,
              ),
            ),
            const SizedBox(height: 8),
            LearnedWordsFilterChips(
              activeFilter: _filter,
              onFilterChanged: _changeFilter,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: LearnedWordsContent(
                loading: _loading,
                error: _error,
                entries: _entries,
                totalPages: _totalPages,
                page: _page,
                search: _search,
                filter: _filter,
                expandedId: _expandedId,
                onRetry: _fetchData,
                onToggleExpand: (id) {
                  setState(() {
                    _expandedId = _expandedId == id ? null : id;
                  });
                },
                onPagePrev: () {
                  setState(() => _page--);
                  _fetchData();
                },
                onPageNext: () {
                  setState(() => _page++);
                  _fetchData();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
