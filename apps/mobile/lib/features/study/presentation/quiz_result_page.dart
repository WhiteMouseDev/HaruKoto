import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/colors.dart';
import '../../../core/theme/text_theme.dart';
import '../../home/providers/home_provider.dart';
import '../data/models/quiz_result_model.dart';
import '../providers/quiz_result_provider.dart';
import '../providers/study_provider.dart';
import 'quiz_launch.dart';
import 'widgets/result_score_display.dart';
import 'widgets/quiz_wrong_answers_status.dart';
import 'widgets/wrong_answer_list.dart';

typedef QuizResultLaunch = Future<void> Function(BuildContext context);

class QuizResultPage extends ConsumerStatefulWidget {
  final QuizResultModel result;
  final String quizType;
  final String jlptLevel;
  final String sessionId;
  final QuizResultLaunch? reviewLauncher;
  final QuizResultLaunch? retryLauncher;
  final bool returnToPreviousResult;
  final bool rewardConfirmed;

  const QuizResultPage({
    super.key,
    required this.result,
    required this.quizType,
    required this.jlptLevel,
    required this.sessionId,
    this.reviewLauncher,
    this.retryLauncher,
    this.returnToPreviousResult = false,
    this.rewardConfirmed = true,
  });

  @override
  ConsumerState<QuizResultPage> createState() => _QuizResultPageState();
}

class _QuizResultPageState extends ConsumerState<QuizResultPage> {
  ProviderContainer? _container;
  bool _openingReview = false;

  @override
  void initState() {
    super.initState();
    _scheduleLoadWrongAnswers();
  }

  @override
  void didUpdateWidget(covariant QuizResultPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionId != widget.sessionId ||
        oldWidget.result.correctCount != widget.result.correctCount ||
        oldWidget.result.totalQuestions != widget.result.totalQuestions) {
      _scheduleLoadWrongAnswers();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _container ??= ProviderScope.containerOf(context, listen: false);
  }

  @override
  void dispose() {
    // Refresh all dependent providers across tabs (deferred to avoid build-phase conflicts)
    final container = _container;
    if (container != null) {
      Future(() {
        container.invalidate(incompleteQuizProvider);
        container.invalidate(smartPreviewProvider(
            (category: 'VOCABULARY', jlptLevel: widget.jlptLevel)));
        container.invalidate(smartPreviewProvider(
            (category: 'GRAMMAR', jlptLevel: widget.jlptLevel)));
        container.invalidate(reviewSummaryProvider(widget.jlptLevel));
        container.invalidate(dashboardProvider);
      });
    }
    super.dispose();
  }

  void _scheduleLoadWrongAnswers() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_loadWrongAnswers());
    });
  }

  Future<void> _loadWrongAnswers() async {
    await ref
        .read(quizResultProvider(widget.sessionId).notifier)
        .loadWrongAnswers(
          wrongCount: _wrongCount,
        );
  }

  Future<void> _saveToWordbook(WrongAnswerModel item) async {
    final sessionId = widget.sessionId;
    final saved = await ref
        .read(quizResultProvider(widget.sessionId).notifier)
        .saveToWordbook(item);
    if (!mounted || widget.sessionId != sessionId || saved) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('단어장에 저장하지 못했습니다')),
    );
  }

  Future<void> _saveAllToWordbook() async {
    final sessionId = widget.sessionId;
    final saved = await ref
        .read(quizResultProvider(widget.sessionId).notifier)
        .saveAllToWordbook();
    if (!mounted || widget.sessionId != sessionId || saved) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('일부 단어를 저장하지 못했습니다')),
    );
  }

  int get _wrongCount =>
      widget.result.totalQuestions - widget.result.correctCount;

  Future<void> _openReview(BuildContext context) async {
    if (_openingReview) return;
    setState(() => _openingReview = true);
    try {
      final launcher = widget.reviewLauncher;
      if (launcher != null) {
        await launcher(context);
      } else {
        await openWrongAnswerReview(
          context,
          sourceSessionId: widget.sessionId,
          quizType: widget.quizType,
          jlptLevel: widget.jlptLevel,
          replace: false,
        );
      }
    } finally {
      if (mounted) setState(() => _openingReview = false);
    }
  }

  Future<void> _retryQuiz(BuildContext context) {
    final launcher = widget.retryLauncher;
    if (launcher != null) {
      return launcher(context);
    }
    return openQuizPageForSession(
      context,
      quizType: widget.quizType,
      jlptLevel: widget.jlptLevel,
      count: 10,
      replace: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final foreground =
        light ? AppColors.redesignForeground : theme.colorScheme.onSurface;
    const actionText = TextStyle(
      fontFamily: redesignFontFamily,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.4,
    );
    final r = widget.result;
    final loadedState = ref.watch(quizResultProvider(widget.sessionId));
    final resultState = loadedState.sessionId == widget.sessionId
        ? loadedState
        : const QuizResultState();
    final wrongCount = _wrongCount;
    final hasWrongAnswers = !resultState.loadingWrong &&
        resultState.error == null &&
        resultState.wrongAnswers.isNotEmpty;
    final navigator = Navigator.of(context);

    return Scaffold(
      backgroundColor: light ? Colors.white : theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  if (navigator.canPop())
                    IconButton(
                      onPressed: navigator.maybePop,
                      tooltip:
                          MaterialLocalizations.of(context).backButtonTooltip,
                      icon: const Icon(LucideIcons.arrowLeft),
                      color: foreground,
                    )
                  else
                    const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          '퀴즈 결과',
                          style: actionText.copyWith(
                              fontSize: 20, color: foreground),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                children: [
                  ResultScoreDisplay(
                    redesigned: true,
                    accuracy: r.accuracy,
                    correct: r.correctCount,
                    total: r.totalQuestions,
                    xpEarned: r.xpEarned,
                    rewardConfirmed: widget.rewardConfirmed,
                    currentXp: r.currentXp,
                    xpForNext: r.xpForNext,
                  ),
                  const SizedBox(height: 40),
                  if (hasWrongAnswers)
                    WrongAnswerList(
                      redesigned: true,
                      wrongAnswers: resultState.wrongAnswers,
                      quizType: widget.quizType,
                      savedWords: resultState.savedWords,
                      onSaveToWordbook: _saveToWordbook,
                      onSaveAll: _saveAllToWordbook,
                    )
                  else
                    QuizWrongAnswersStatus(
                      loading: resultState.loadingWrong,
                      wrongCount: wrongCount,
                      error: resultState.error,
                      onRetry: () => unawaited(_loadWrongAnswers()),
                    ),
                  if (wrongCount > 0 && hasWrongAnswers) ...[
                    const SizedBox(height: 40),
                    FilledButton(
                      onPressed: _openingReview
                          ? null
                          : () => unawaited(_openReview(context)),
                      style: FilledButton.styleFrom(
                        backgroundColor: light
                            ? const Color(0xFFFEF0F2)
                            : AppColors.quizWrongBgDark,
                        foregroundColor:
                            light ? foreground : AppColors.quizWrongTextDark,
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        textStyle: actionText,
                      ),
                      child: Row(
                        children: [
                          Image.asset(
                            'assets/icons/figma-quiz-result-review.png',
                            width: 14,
                            height: 16,
                            excludeFromSemantics: true,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(LucideIcons.fileX, size: 14),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(child: Text('오답 복습하기')),
                          const SizedBox(width: 8),
                          const Icon(LucideIcons.chevronRight, size: 16),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                  FilledButton.icon(
                    onPressed: () => unawaited(_retryQuiz(context)),
                    icon: Image.asset(
                      'assets/icons/figma-quiz-result-retry.png',
                      width: 20,
                      height: 20,
                      excludeFromSemantics: true,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(LucideIcons.rotateCcw, size: 20),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: light ? AppColors.brandPink : null,
                      foregroundColor: light ? Colors.white : null,
                      shape: const StadiumBorder(),
                      textStyle: actionText,
                    ),
                    label: const Text('한 번 더 도전', textAlign: TextAlign.center),
                  ),
                  if (widget.returnToPreviousResult) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: navigator.pop,
                      icon: const Icon(LucideIcons.arrowLeft, size: 16),
                      label: const Text('이전 퀴즈 결과로 돌아가기'),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () =>
                        navigator.popUntil((route) => route.isFirst),
                    icon: Image.asset(
                      'assets/icons/home-nav-home.png',
                      width: 16,
                      height: 16,
                      color: foreground,
                      excludeFromSemantics: true,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(LucideIcons.home, size: 16),
                    ),
                    label: const Text('홈으로 돌아가기', textAlign: TextAlign.center),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      foregroundColor: foreground,
                      shape: const StadiumBorder(),
                      textStyle: actionText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
