import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/providers/user_preferences_provider.dart';
import '../data/models/word_entry_model.dart';
import '../providers/study_provider.dart';
import 'quiz_launch.dart';
import 'widgets/wrong_answers_content.dart';
import 'widgets/wrong_answers_overview.dart';
import 'widgets/wrong_answers_sort_chips.dart';

class WrongAnswersPage extends ConsumerStatefulWidget {
  const WrongAnswersPage({super.key});

  @override
  ConsumerState<WrongAnswersPage> createState() => _WrongAnswersPageState();
}

class _WrongAnswersPageState extends ConsumerState<WrongAnswersPage> {
  List<WrongEntryModel> _entries = [];
  WrongAnswersSummary? _summary;
  int _totalPages = 1;
  int _page = 1;
  String _sort = 'most-wrong';
  bool _loading = true;
  String? _error;
  String? _expandedId;
  final Set<String> _savedWords = {};

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = ref.read(studyRepositoryProvider);
    try {
      final data = await repo.fetchWrongAnswers(
        page: _page,
        sort: _sort,
      );
      if (!mounted) return;
      setState(() {
        _entries = data.entries;
        _summary = data.summary;
        _totalPages = data.totalPages;
        _loading = false;
      });
    } catch (e, stackTrace) {
      unawaited(Sentry.captureException(e, stackTrace: stackTrace));
      if (!mounted) return;
      setState(() {
        _error = '데이터를 불러올 수 없습니다';
        _loading = false;
      });
    }
  }

  Future<void> _saveToWordbook(WrongEntryModel entry) async {
    if (_savedWords.contains(entry.vocabularyId)) return;
    final repo = ref.read(studyRepositoryProvider);
    try {
      await repo.addWord(
        word: entry.word,
        reading: entry.reading,
        meaningKo: entry.meaningKo,
        source: 'QUIZ',
      );
      setState(() => _savedWords.add(entry.vocabularyId));
    } catch (e) {
      debugPrint('[WrongAnswersPage] Failed to save word: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('단어장에 저장하지 못했습니다')),
        );
      }
    }
  }

  void _changeSort(String sort) {
    if (_sort == sort) return;
    setState(() {
      _sort = sort;
      _page = 1;
    });
    _fetchData();
  }

  void _startReviewQuiz() {
    final summary = _summary;
    if (summary == null || summary.remaining <= 0) return;

    final level = ref.read(userPreferencesProvider).jlptLevel;
    openQuizPageForSession(
      context,
      quizType: 'VOCABULARY',
      jlptLevel: level,
      count: summary.remaining.clamp(1, 20),
      mode: 'review',
    );
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
                    '오답 노트',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (_summary != null)
              WrongAnswersOverview(
                summary: _summary!,
                onStartReview: _startReviewQuiz,
              ),
            WrongAnswersSortChips(
              activeSort: _sort,
              onSortChanged: _changeSort,
            ),
            Expanded(
              child: WrongAnswersContent(
                loading: _loading,
                error: _error,
                entries: _entries,
                totalPages: _totalPages,
                page: _page,
                expandedId: _expandedId,
                savedWords: _savedWords,
                onRetry: _fetchData,
                onToggleExpand: (id) {
                  setState(() {
                    _expandedId = _expandedId == id ? null : id;
                  });
                },
                onSaveToWordbook: _saveToWordbook,
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
