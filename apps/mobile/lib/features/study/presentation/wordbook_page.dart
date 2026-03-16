import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../../core/constants/sizes.dart';
import '../../../shared/widgets/app_error_retry.dart';
import '../../../shared/widgets/pagination_footer.dart';
import '../data/models/wordbook_entry_model.dart';
import '../providers/study_provider.dart';
import 'widgets/add_word_dialog.dart';
import 'widgets/wordbook_entry_card.dart';

class WordbookPage extends ConsumerStatefulWidget {
  const WordbookPage({super.key});

  @override
  ConsumerState<WordbookPage> createState() => _WordbookPageState();
}

class _WordbookPageState extends ConsumerState<WordbookPage> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _search = '';
  final String _sort = 'recent';
  String _filter = 'ALL';
  int _page = 1;

  List<WordbookEntryModel> _entries = [];
  int _totalPages = 1;
  bool _loading = true;
  String? _error;

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
      final data = await repo.fetchWordbook(
        page: _page,
        sort: _sort,
        search: _search,
        filter: _filter,
      );
      if (!mounted) return;
      setState(() {
        _entries = data.entries;
        _totalPages = data.totalPages;
        _loading = false;
      });
    } catch (e, stackTrace) {
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));
      if (!mounted) return;
      setState(() {
        _error = '단어장을 불러올 수 없습니다.';
        _loading = false;
      });
    }
  }

  Future<void> _deleteWord(String id) async {
    final repo = ref.read(studyRepositoryProvider);
    try {
      await repo.deleteWord(id);
      unawaited(_fetchData());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제되었습니다')),
        );
      }
    } catch (e) {
      debugPrint('[WordbookPage] Failed to delete word: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('삭제에 실패했습니다')),
        );
      }
    }
  }

  void _showAddDialog() {
    showAddWordDialog(context, ref, onAdded: _fetchData);
  }

  static const _filterOptions = [
    ('ALL', '전체'),
    ('QUIZ', '퀴즈'),
    ('CONVERSATION', '회화'),
    ('MANUAL', '직접 추가'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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

            // Search
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
            const SizedBox(height: 8),

            // Filter chips
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _filterOptions.map((f) {
                  final isActive = _filter == f.$1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
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
                          borderRadius: BorderRadius.circular(20),
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

            // Content
            Expanded(
              child: _WordbookContent(
                loading: _loading,
                error: _error,
                entries: _entries,
                totalPages: _totalPages,
                page: _page,
                search: _search,
                filter: _filter,
                onRetry: _fetchData,
                onAddFirst: _showAddDialog,
                onDelete: _deleteWord,
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

class _WordbookContent extends StatelessWidget {
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

  const _WordbookContent({
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
    final theme = Theme.of(context);

    if (loading) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: List.generate(
          5,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      );
    }

    if (error != null) {
      return AppErrorRetry(
        onRetry: onRetry,
        message: error,
      );
    }

    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.bookMarked,
                size: 48,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              search.isNotEmpty || filter != 'ALL'
                  ? '검색 결과가 없어요'
                  : '단어장이 비어있어요',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            if (search.isEmpty && filter == 'ALL') ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onAddFirst,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: const Text('첫 단어 추가하기'),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: WordbookEntryCard(
                  entry: entry,
                  onDelete: () => onDelete(entry.id),
                ),
              );
            },
          ),
        ),
        PaginationFooter(
          page: page,
          totalPages: totalPages,
          onPagePrev: onPagePrev,
          onPageNext: onPageNext,
        ),
      ],
    );
  }
}
