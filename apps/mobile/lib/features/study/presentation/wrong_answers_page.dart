import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/providers/user_preferences_provider.dart';
import '../data/models/word_entry_model.dart';
import '../providers/wrong_answers_provider.dart';
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
  @override
  void initState() {
    super.initState();
    unawaited(ref.read(wrongAnswersProvider.notifier).refresh());
  }

  Future<void> _saveToWordbook(WrongEntryModel entry) async {
    final saved =
        await ref.read(wrongAnswersProvider.notifier).saveToWordbook(entry);
    if (!mounted || saved) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('단어장에 저장하지 못했습니다')),
    );
  }

  void _changeSort(String sort) {
    unawaited(ref.read(wrongAnswersProvider.notifier).changeSort(sort));
  }

  void _startReviewQuiz(WrongAnswersSummary? summary) {
    if (summary == null || summary.remaining <= 0) {
      return;
    }

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
    final wrongAnswers = ref.watch(wrongAnswersProvider);
    final wrongAnswersController = ref.read(wrongAnswersProvider.notifier);

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
            if (wrongAnswers.summary != null)
              WrongAnswersOverview(
                summary: wrongAnswers.summary!,
                onStartReview: () => _startReviewQuiz(wrongAnswers.summary),
              ),
            WrongAnswersSortChips(
              activeSort: wrongAnswers.sort,
              onSortChanged: _changeSort,
            ),
            Expanded(
              child: WrongAnswersContent(
                loading: wrongAnswers.loading,
                error: wrongAnswers.error,
                entries: wrongAnswers.entries,
                totalPages: wrongAnswers.totalPages,
                page: wrongAnswers.page,
                expandedId: wrongAnswers.expandedId,
                savedWords: wrongAnswers.savedWords,
                onRetry: wrongAnswersController.refresh,
                onToggleExpand: wrongAnswersController.toggleExpanded,
                onSaveToWordbook: _saveToWordbook,
                onPagePrev: wrongAnswersController.previousPage,
                onPageNext: wrongAnswersController.nextPage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
