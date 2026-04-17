import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../../../core/providers/user_preferences_provider.dart';
import '../data/models/lesson_models.dart';
import '../domain/lesson_flow_policy.dart';
import '../providers/lesson_session_provider.dart';
import '../providers/study_provider.dart';
import 'widgets/lesson_learning_steps.dart';
import 'widgets/lesson_intro_steps.dart';
import 'widgets/lesson_practice_steps.dart';

/// 레슨 학습 플로우: 6-Step (상황 프리뷰 → 가이드 리딩 → 이해 체크 → 매칭 게임 → 문장 재구성 → 결과)
class LessonPage extends ConsumerStatefulWidget {
  final String lessonId;
  const LessonPage({super.key, required this.lessonId});

  @override
  ConsumerState<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends ConsumerState<LessonPage> {
  static const _totalSteps = 8;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(lessonDetailProvider(widget.lessonId));
    final session = ref.watch(lessonSessionProvider(widget.lessonId));

    return PopScope(
      canPop: session.canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ref.read(lessonSessionProvider(widget.lessonId).notifier).goBack();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: detailAsync.when(
            data: (d) => Text(d.title),
            loading: () => const Text('레슨'),
            error: (_, __) => const Text('레슨'),
          ),
          leading: IconButton(
            icon: const Icon(LucideIcons.x),
            onPressed: () => context.pop(),
          ),
        ),
        body: detailAsync.when(
          data: (detail) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.md,
                  vertical: AppSizes.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: LessonStepProgressBar(
                        currentStep: session.step.index,
                        totalSteps: _totalSteps,
                      ),
                    ),
                    if (session.showDialogueShortcut) ...[
                      const SizedBox(width: AppSizes.sm),
                      GestureDetector(
                        onTap: () => showLessonDialogueSheet(context, detail),
                        child: const Icon(
                          LucideIcons.messageSquare,
                          size: 18,
                          color: AppColors.primaryStrong,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildStep(
                    context,
                    ref,
                    detail,
                    session,
                  ),
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('오류: $e')),
        ),
      ),
    );
  }

  Widget _buildStep(
    BuildContext context,
    WidgetRef ref,
    LessonDetailModel detail,
    LessonSessionState session,
  ) {
    switch (session.step) {
      case LessonStep.contextPreview:
        return LessonContextPreviewStep(
          key: const ValueKey('step-0'),
          detail: detail,
          onNext: () => ref
              .read(lessonSessionProvider(widget.lessonId).notifier)
              .goToVocabLearning(),
        );
      case LessonStep.vocabLearning:
        return LessonVocabLearningStep(
          key: const ValueKey('step-vocab'),
          vocabItems: detail.vocabItems,
          onBackToPrev: () => ref
              .read(lessonSessionProvider(widget.lessonId).notifier)
              .goBack(),
          onNext: () {
            if (detail.grammarItems.isNotEmpty) {
              ref
                  .read(lessonSessionProvider(widget.lessonId).notifier)
                  .goToGrammarLearning();
            } else {
              ref
                  .read(lessonSessionProvider(widget.lessonId).notifier)
                  .goToGuidedReading();
            }
          },
        );
      case LessonStep.grammarLearning:
        return LessonGrammarLearningStep(
          key: const ValueKey('step-grammar'),
          grammarItems: detail.grammarItems,
          onBackToPrev: () => ref
              .read(lessonSessionProvider(widget.lessonId).notifier)
              .goBack(),
          onNext: () => ref
              .read(lessonSessionProvider(widget.lessonId).notifier)
              .goToGuidedReading(),
        );
      case LessonStep.guidedReading:
        return LessonGuidedReadingStep(
          key: const ValueKey('step-1'),
          detail: detail,
          onNext: () {
            unawaited(
              ref
                  .read(lessonSessionProvider(widget.lessonId).notifier)
                  .startPractice(detail),
            );
          },
        );
      case LessonStep.recognition:
        final recognitionQs = lessonRecognitionQuestions(detail);
        if (recognitionQs.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref
                .read(lessonSessionProvider(widget.lessonId).notifier)
                .skipRecognition();
          });
          return const SizedBox.shrink(key: ValueKey('step-2-skip'));
        }
        return LessonRecognitionCheckStep(
          key: ValueKey('step-2-${session.recognitionIndex}'),
          questions: recognitionQs,
          currentIndex: session.recognitionIndex,
          totalSteps: _totalSteps,
          onAnswer: (answer) => ref
              .read(lessonSessionProvider(widget.lessonId).notifier)
              .answerRecognition(detail, answer),
        );
      case LessonStep.matching:
        return LessonMatchingGameStep(
          key: const ValueKey('step-3'),
          vocabItems: detail.vocabItems,
          onComplete: () {
            unawaited(_handleMatchingComplete(context, ref, detail));
          },
        );
      case LessonStep.sentenceReorder:
        final reorderQs = lessonReorderQuestions(detail);
        if (reorderQs.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(_submitLesson(context, ref, detail));
          });
          return const SizedBox.shrink(key: ValueKey('step-4-skip'));
        }
        return LessonSentenceReorderStep(
          key: ValueKey('step-4-${session.reorderIndex}'),
          questions: reorderQs,
          currentIndex: session.reorderIndex,
          totalSteps: _totalSteps,
          vocabItems: detail.vocabItems,
          onAnswer: (answer) => _handleReorderAnswer(
            context,
            ref,
            detail,
            answer,
          ),
        );
      case LessonStep.result:
        return _ResultStep(
          key: const ValueKey('step-5'),
          result: session.result!,
          detail: detail,
          onRetry: () =>
              ref.read(lessonSessionProvider(widget.lessonId).notifier).reset(),
          onDone: () => context.pop(),
        );
    }
  }

  Future<void> _handleMatchingComplete(
    BuildContext context,
    WidgetRef ref,
    LessonDetailModel detail,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final level = ref.read(userPreferencesProvider).jlptLevel;
      await ref
          .read(lessonSessionProvider(widget.lessonId).notifier)
          .completeMatching(
            detail: detail,
            jlptLevel: level,
          );
    } catch (e) {
      _showSubmitError(messenger, e);
    }
  }

  Future<void> _handleReorderAnswer(
    BuildContext context,
    WidgetRef ref,
    LessonDetailModel detail,
    Map<String, dynamic> answer,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final level = ref.read(userPreferencesProvider).jlptLevel;
      await ref
          .read(lessonSessionProvider(widget.lessonId).notifier)
          .answerReorder(
            detail: detail,
            jlptLevel: level,
            answer: answer,
          );
    } catch (e) {
      _showSubmitError(messenger, e);
    }
  }

  Future<void> _submitLesson(
    BuildContext context,
    WidgetRef ref,
    LessonDetailModel detail,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final level = ref.read(userPreferencesProvider).jlptLevel;
      await ref
          .read(lessonSessionProvider(widget.lessonId).notifier)
          .submitAnswers(
            lessonId: detail.id,
            jlptLevel: level,
          );
    } catch (e) {
      _showSubmitError(messenger, e);
    }
  }

  void _showSubmitError(ScaffoldMessengerState? messenger, Object error) {
    messenger?.showSnackBar(
      SnackBar(content: Text('제출 실패: $error')),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Step 5: _ResultStep
// ═══════════════════════════════════════════════════════════════════

// ── Step: Result (결과) ──

class _ResultStep extends StatefulWidget {
  final LessonSubmitResultModel result;
  final LessonDetailModel detail;
  final VoidCallback onRetry;
  final VoidCallback onDone;
  const _ResultStep({
    super.key,
    required this.result,
    required this.detail,
    required this.onRetry,
    required this.onDone,
  });

  @override
  State<_ResultStep> createState() => _ResultStepState();
}

class _ResultStepState extends State<_ResultStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _staggerController.forward();
    });
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Widget _staggered(int index, Widget child) {
    final start = (index * 0.1).clamp(0.0, 0.7);
    final end = (start + 0.35).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: _staggerController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Opacity(
        opacity: animation.value,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - animation.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final detail = widget.detail;
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final score = result.scoreTotal > 0
        ? (result.scoreCorrect / result.scoreTotal * 100).round()
        : 0;
    final isPerfect = result.scoreCorrect == result.scoreTotal;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSizes.md),
            children: [
              const SizedBox(height: AppSizes.lg),
              _staggered(
                0,
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isPerfect
                          ? AppColors.success(brightness)
                              .withValues(alpha: 0.12)
                          : AppColors.primary.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      isPerfect
                          ? LucideIcons.trophy
                          : LucideIcons.clipboardCheck,
                      size: 36,
                      color: isPerfect
                          ? AppColors.success(brightness)
                          : AppColors.primaryStrong,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.md),
              _staggered(
                1,
                Center(
                  child: TweenAnimationBuilder<int>(
                    tween: IntTween(begin: 0, end: score),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => Text(
                      '$value%',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              _staggered(
                1,
                Center(
                  child: Text(
                    '${result.scoreCorrect}/${result.scoreTotal} 정답',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.lightSubtext,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSizes.md),

              // SRS registration card
              if (result.srsItemsRegistered > 0)
                _staggered(
                  2,
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSizes.md),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.md,
                      vertical: AppSizes.gap,
                    ),
                    decoration: BoxDecoration(
                      color:
                          AppColors.success(brightness).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      border: Border.all(
                        color: AppColors.success(brightness)
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.checkCircle2,
                          color: AppColors.success(brightness),
                          size: AppSizes.iconMd,
                        ),
                        const SizedBox(width: AppSizes.sm),
                        Expanded(
                          child: Text(
                            '${result.srsItemsRegistered}개 항목이 복습 예약되었습니다',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: AppSizes.sm),

              // Per-question results
              ...result.results.asMap().entries.map((entry) {
                final r = entry.value;
                final q = detail.content.questions.firstWhere(
                  (q) => q.order == r.order,
                  orElse: () => detail.content.questions.first,
                );
                return _staggered(
                  entry.key + 3,
                  Card(
                    margin: const EdgeInsets.only(bottom: AppSizes.sm),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSizes.gap),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                r.isCorrect
                                    ? LucideIcons.checkCircle2
                                    : LucideIcons.xCircle,
                                color: r.isCorrect
                                    ? AppColors.success(brightness)
                                    : AppColors.error(brightness),
                                size: AppSizes.iconMd,
                              ),
                              const SizedBox(width: AppSizes.sm),
                              Expanded(
                                child: Text(
                                  q.prompt,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                          if (r.explanation != null) ...[
                            const SizedBox(height: AppSizes.xs),
                            Padding(
                              padding: const EdgeInsets.only(left: 28),
                              child: Text(
                                r.explanation!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.lightSubtext,
                                ),
                              ),
                            ),
                          ],
                          // SRS state transition
                          if (r.stateBefore != null &&
                              r.stateAfter != null) ...[
                            const SizedBox(height: AppSizes.sm),
                            Padding(
                              padding: const EdgeInsets.only(left: 28),
                              child: Row(
                                children: [
                                  Icon(
                                    _srsTransitionIcon(
                                        r.stateBefore!, r.stateAfter!),
                                    size: 14,
                                    color: _srsTransitionColor(
                                      brightness,
                                      r.stateBefore!,
                                      r.stateAfter!,
                                    ),
                                  ),
                                  const SizedBox(width: AppSizes.xs),
                                  Text(
                                    '${r.stateBefore} → ${r.stateAfter}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: _srsTransitionColor(
                                        brightness,
                                        r.stateBefore!,
                                        r.stateAfter!,
                                      ),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (r.isProvisionalPhase) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.warning(brightness)
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'SRS 등록됨',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: AppColors.warning(brightness),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                          // Next review date
                          if (r.nextReviewAt != null) ...[
                            const SizedBox(height: AppSizes.xs),
                            Padding(
                              padding: const EdgeInsets.only(left: 28),
                              child: Text(
                                '다음 복습: ${_formatReviewDate(r.nextReviewAt!)}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColors.lightSubtext,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: widget.onDone,
                    icon: const Icon(LucideIcons.bookOpen, size: 18),
                    label: const Text('학습으로 돌아가기'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryStrong,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: widget.onRetry,
                        child: const Text('다시 풀기'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  IconData _srsTransitionIcon(String before, String after) {
    if (before == 'UNSEEN') return LucideIcons.sparkles;
    if (after == 'REVIEW' || after == 'MASTERED') return LucideIcons.trendingUp;
    if (after == 'RELEARNING') return LucideIcons.refreshCw;
    return LucideIcons.arrowLeftRight;
  }

  Color _srsTransitionColor(
      Brightness brightness, String before, String after) {
    if (after == 'MASTERED') return AppColors.success(brightness);
    if (after == 'REVIEW') return AppColors.info(brightness);
    if (after == 'LEARNING') return AppColors.warning(brightness);
    if (after == 'RELEARNING') return AppColors.error(brightness);
    if (after == 'PROVISIONAL') return AppColors.warning(brightness);
    return AppColors.lightSubtext;
  }

  String _formatReviewDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = date.difference(now);
      if (diff.inMinutes < 60) return '${diff.inMinutes}분 후';
      if (diff.inHours < 24) return '${diff.inHours}시간 후';
      if (diff.inDays < 7) return '${diff.inDays}일 후';
      return '${date.month}/${date.day}';
    } catch (_) {
      return isoDate;
    }
  }
}
