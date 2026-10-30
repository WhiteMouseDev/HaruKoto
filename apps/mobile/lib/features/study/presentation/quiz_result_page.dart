import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/colors.dart';
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

  const QuizResultPage({
    super.key,
    required this.result,
    required this.quizType,
    required this.jlptLevel,
    required this.sessionId,
    this.reviewLauncher,
    this.retryLauncher,
    this.returnToPreviousResult = false,
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

  String get _resultMessage {
    if (widget.result.accuracy >= 80) return '훌륭해요!';
    if (widget.result.accuracy >= 50) return '잘 하셨어요!';
    return '다음엔 더 잘할 수 있어요!';
  }

  IconData get _resultIcon {
    if (widget.result.accuracy >= 80) return LucideIcons.partyPopper;
    if (widget.result.accuracy >= 50) return LucideIcons.thumbsUp;
    return LucideIcons.dumbbell;
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
    final r = widget.result;
    final loadedState = ref.watch(quizResultProvider(widget.sessionId));
    final resultState = loadedState.sessionId == widget.sessionId
        ? loadedState
        : const QuizResultState();
    final wrongCount = _wrongCount;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              children: [
                // Icon & message
                Center(
                  child: Column(
                    children: [
                      Icon(
                        _resultIcon,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _resultMessage,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Score display
                ResultScoreDisplay(
                  accuracy: r.accuracy,
                  correct: r.correctCount,
                  total: r.totalQuestions,
                  xpEarned: r.xpEarned,
                  currentXp: r.currentXp,
                  xpForNext: r.xpForNext,
                ),

                const SizedBox(height: 20),

                // Wrong answers
                if (!resultState.loadingWrong &&
                    resultState.error == null &&
                    resultState.wrongAnswers.isNotEmpty)
                  WrongAnswerList(
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

                // Next recommendations
                if (wrongCount > 0 &&
                    !resultState.loadingWrong &&
                    resultState.error == null &&
                    resultState.wrongAnswers.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(
                    '다음에 이걸 해보세요',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: AppColors.error(theme.brightness)
                        .withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _openingReview
                          ? null
                          : () {
                              unawaited(_openReview(context));
                            },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.error(theme.brightness)
                                .withValues(alpha: 0.3),
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(LucideIcons.fileX,
                                    size: 16,
                                    color: AppColors.error(theme.brightness)),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(
                                  '이번 퀴즈의 오답 복습',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                )),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${resultState.wrongAnswers.length}개 항목',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '오답 복습 →',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.error(theme.brightness),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Action buttons
                FilledButton.icon(
                  onPressed: () {
                    unawaited(_retryQuiz(context));
                  },
                  icon: const Icon(LucideIcons.rotateCcw, size: 16),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    textStyle: theme.textTheme.labelLarge
                        ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                    backgroundColor: theme.brightness == Brightness.light
                        ? AppColors.sakuraContainer
                        : Color.alphaBlend(
                            AppColors.primary.withValues(alpha: 0.22),
                            AppColors.darkCard),
                    foregroundColor: theme.brightness == Brightness.light
                        ? AppColors.sakuraOn
                        : AppColors.sakuraContainer,
                  ),
                  label: const Text('한 번 더 도전'),
                ),
                const SizedBox(height: 8),
                if (widget.returnToPreviousResult) ...[
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.arrowLeft, size: 16),
                    label: const Text('이전 퀴즈 결과로 돌아가기'),
                  ),
                  const SizedBox(height: 8),
                ],
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(LucideIcons.home, size: 16),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    textStyle:
                        theme.textTheme.labelLarge?.copyWith(fontSize: 16),
                    foregroundColor: theme.brightness == Brightness.light
                        ? AppColors.lightSubtext
                        : AppColors.darkSubtext,
                  ),
                  label: const Text('홈으로 돌아가기'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
