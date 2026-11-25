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
  final _search = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref.read(wrongAnswersProvider.notifier).refresh());
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _saveToWordbook(WrongEntryModel entry) async {
    final saved =
        await ref.read(wrongAnswersProvider.notifier).saveToWordbook(entry);
    if (!mounted || saved) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('단어장에 저장하지 못했습니다')),
    );
  }

  void _fromTop(Future<void> Function() action) {
    FocusScope.of(context).unfocus();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    unawaited(action());
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
    ref.listen(
      wrongAnswersProvider.select((state) => state.supportsSearchAndStatus),
      (previous, supported) {
        if (previous == true && !supported) _search.clear();
      },
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: false,
        toolbarHeight: 66,
        leadingWidth: 52,
        titleSpacing: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: foreground,
        leading: Padding(
          padding: const EdgeInsetsDirectional.only(start: 8),
          child: IconButton(
            onPressed: () => Navigator.maybePop(context),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(LucideIcons.arrowLeft, size: 20),
          ),
        ),
        title: const Text(
          '오답노트',
          style: TextStyle(
            fontFamily: redesignFontFamily,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: WrongAnswersContent(
          state: wrongAnswers,
          searchController: _search,
          scrollController: _scroll,
          onRetry: controller.refresh,
          onOpenStudy: _openStudy,
          onStartReview: _startReviewQuiz,
          onSearchChanged: controller.changeSearch,
          onStatusChanged: controller.changeStatus,
          onClearFilters: () {
            _search.clear();
            unawaited(controller.clearFilters());
          },
          onSortChanged: (sort) {
            if (sort != wrongAnswers.sort) {
              _fromTop(() => controller.changeSort(sort));
            }
          },
          onToggleExpand: controller.toggleExpanded,
          onSaveToWordbook: _saveToWordbook,
          onPagePrev: () => _fromTop(controller.previousPage),
          onPageNext: () => _fromTop(controller.nextPage),
        ),
      ),
    );
  }
}
