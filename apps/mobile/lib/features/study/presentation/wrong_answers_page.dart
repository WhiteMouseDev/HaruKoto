import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/colors.dart';
import '../data/models/word_entry_model.dart';
import '../providers/study_provider.dart';
import 'quiz_page.dart';
import 'widgets/wrong_answers_content.dart';
import 'widgets/wrong_answers_summary_card.dart';

class WrongAnswersPage extends ConsumerStatefulWidget {
  const WrongAnswersPage({super.key});

  @override
  ConsumerState<WrongAnswersPage> createState() =>
      _WrongAnswersPageState();
}

class _WrongAnswersPageState
    extends ConsumerState<WrongAnswersPage> {
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
      setState(() {
        _entries = data.entries;
        _summary = data.summary;
        _totalPages = data.totalPages;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[WrongAnswersPage] Failed to fetch data: $e');
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

  static const _sortOptions = [
    ('most-wrong', '많이 틀린 순'),
    ('recent', '최근 순'),
    ('alphabetical', '가나다 순'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () =>
                        Navigator.of(context).pop(),
                    child: const Icon(
                        LucideIcons.arrowLeft, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '오답 노트',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (_summary != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16),
                child: Row(
                  children: [
                    WrongAnswersSummaryCard(
                        label: '전체',
                        value:
                            '${_summary!.totalWrong}',
                        theme: theme),
                    const SizedBox(width: 8),
                    WrongAnswersSummaryCard(
                        label: '아직 학습중',
                        value:
                            '${_summary!.remaining}',
                        theme: theme,
                        valueColor: AppColors.error(
                            theme.brightness)),
                    const SizedBox(width: 8),
                    WrongAnswersSummaryCard(
                        label: '극복 완료',
                        value:
                            '${_summary!.mastered}',
                        theme: theme,
                        valueColor:
                            theme.colorScheme.primary),
                  ],
                ),
              ),
            if (_summary != null &&
                _summary!.remaining > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    16, 12, 16, 0),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).push(
                        quizRoute(const QuizPage(
                          quizType: 'VOCABULARY',
                          jlptLevel: 'N5',
                          count: 10,
                          mode: 'review',
                        )),
                      );
                    },
                    icon: const Icon(
                        LucideIcons.rotateCcw, size: 16),
                    label: const Text('오답 복습 퀴즈 시작'),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  16, 12, 16, 8),
              child: Row(
                children: _sortOptions.map((opt) {
                  final isActive = _sort == opt.$1;
                  return Padding(
                    padding:
                        const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _sort = opt.$1;
                          _page = 1;
                        });
                        _fetchData();
                      },
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6),
                        decoration: BoxDecoration(
                          color: isActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme
                                  .surfaceContainerHigh,
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        child: Text(
                          opt.$2,
                          style: theme
                              .textTheme.labelSmall
                              ?.copyWith(
                            color: isActive
                                ? theme.colorScheme
                                    .onPrimary
                                : theme.colorScheme
                                    .onSurface
                                    .withValues(
                                        alpha: 0.5),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
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
                    _expandedId =
                        _expandedId == id ? null : id;
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
