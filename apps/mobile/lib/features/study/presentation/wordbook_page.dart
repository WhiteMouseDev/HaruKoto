import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../../core/constants/sizes.dart';
import '../data/models/wordbook_entry_model.dart';
import '../providers/study_provider.dart';
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
              activeFilter: _filter,
              onFilterChanged: _changeFilter,
            ),
            const SizedBox(height: 12),

            Expanded(
              child: WordbookContent(
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
