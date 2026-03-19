import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../data/models/word_entry_model.dart';
import '../providers/study_provider.dart';
import 'widgets/learned_words_content.dart';
import 'widgets/learned_words_sort_tabs.dart';
import 'widgets/learned_words_summary_tile.dart';

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

  static const _filterOptions = [
    ('ALL', '전체'),
    ('MASTERED', '마스터'),
    ('LEARNING', '학습중'),
  ];

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
            if (_summary != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    LearnedWordsSummaryTile(
                        label: '전체',
                        value: '${_summary!.totalLearned}',
                        theme: theme),
                    const SizedBox(width: 8),
                    LearnedWordsSummaryTile(
                        label: '마스터',
                        value: '${_summary!.mastered}',
                        theme: theme,
                        valueColor: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    LearnedWordsSummaryTile(
                        label: '학습중',
                        value: '${_summary!.learning}',
                        theme: theme,
                        valueColor: AppColors.info(theme.brightness)),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: '단어 검색...',
                  prefixIcon: const Icon(LucideIcons.search, size: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSizes.inputRadius),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LearnedWordsSortTabs(
                sortOptions: _sortOptions,
                activeSort: _sort,
                onSortChanged: (sort) {
                  setState(() {
                    _sort = sort;
                    _page = 1;
                  });
                  _fetchData();
                },
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: _filterOptions.map((f) {
                  final isActive = _filter == f.$1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _filter = f.$1;
                          _page = 1;
                        });
                        _fetchData();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive
                              ? theme.colorScheme.primary.withValues(alpha: 0.1)
                              : Colors.transparent,
                          border: Border.all(
                            color: isActive
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                          ),
                          borderRadius:
                              BorderRadius.circular(AppSizes.chipRadius),
                        ),
                        child: Text(
                          f.$2,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: isActive
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
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
