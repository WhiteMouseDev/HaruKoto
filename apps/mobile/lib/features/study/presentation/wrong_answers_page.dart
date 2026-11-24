import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/providers/user_preferences_provider.dart';
import '../../../core/theme/text_theme.dart';
import '../data/models/word_entry_model.dart';
import '../providers/wrong_answers_provider.dart';
import 'quiz_launch.dart';
import 'widgets/wrong_answers_content.dart';

class WrongAnswersPage extends ConsumerStatefulWidget {
  const WrongAnswersPage({super.key});

  @override
  ConsumerState<WrongAnswersPage> createState() => _WrongAnswersPageState();
}

class _WrongAnswersPageState extends ConsumerState<WrongAnswersPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(wrongAnswersProvider.notifier).refresh());
    });
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

  void _startReviewQuiz(WrongAnswersSummary summary) {
    if (summary.remaining <= 0) return;
    final level = ref.read(userPreferencesProvider).jlptLevel;
    openQuizPageForSession(
      context,
      quizType: 'VOCABULARY',
      jlptLevel: level,
      count: summary.remaining.clamp(1, 20),
      mode: 'review',
    );
  }

  void _openStudy() {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.go('/study');
    } else {
      unawaited(Navigator.maybePop(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = theme.brightness == Brightness.light
        ? AppColors.redesignForeground
        : theme.colorScheme.onSurface;
    final wrongAnswers = ref.watch(wrongAnswersProvider);
    final controller = ref.read(wrongAnswersProvider.notifier);

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
          '오답노트',
          style: TextStyle(
            fontFamily: redesignFontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: WrongAnswersContent(
          state: wrongAnswers,
          onRetry: controller.refresh,
          onOpenStudy: _openStudy,
          onStartReview: _startReviewQuiz,
          onSortChanged: _changeSort,
          onToggleExpand: controller.toggleExpanded,
          onSaveToWordbook: _saveToWordbook,
          onPagePrev: controller.previousPage,
          onPageNext: controller.nextPage,
        ),
      ),
    );
  }
}
