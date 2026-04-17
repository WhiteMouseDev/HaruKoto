import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/sizes.dart';
import '../data/models/lesson_models.dart';
import '../domain/lesson_flow_policy.dart';
import '../providers/lesson_session_provider.dart';
import '../providers/study_provider.dart';
import 'widgets/lesson_learning_steps.dart';
import 'widgets/lesson_intro_steps.dart';
import 'widgets/lesson_practice_steps.dart';
import 'widgets/lesson_result_step.dart';

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
    final sessionNotifier =
        ref.read(lessonSessionProvider(widget.lessonId).notifier);

    ref.listen<LessonSessionState>(
      lessonSessionProvider(widget.lessonId),
      (previous, next) {
        final nextError = next.submissionErrorMessage;
        if (nextError == null ||
            nextError == previous?.submissionErrorMessage) {
          return;
        }
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(nextError)),
        );
        sessionNotifier.clearSubmissionError();
      },
    );

    return PopScope(
      canPop: session.canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          sessionNotifier.goBack();
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
            unawaited(
              ref
                  .read(lessonSessionProvider(widget.lessonId).notifier)
                  .completeMatching(detail: detail),
            );
          },
        );
      case LessonStep.sentenceReorder:
        final reorderQs = lessonReorderQuestions(detail);
        if (reorderQs.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(
              ref
                  .read(lessonSessionProvider(widget.lessonId).notifier)
                  .submitAnswers(lessonId: detail.id),
            );
          });
          return const SizedBox.shrink(key: ValueKey('step-4-skip'));
        }
        return LessonSentenceReorderStep(
          key: ValueKey('step-4-${session.reorderIndex}'),
          questions: reorderQs,
          currentIndex: session.reorderIndex,
          totalSteps: _totalSteps,
          vocabItems: detail.vocabItems,
          onAnswer: (answer) => ref
              .read(lessonSessionProvider(widget.lessonId).notifier)
              .answerReorder(
                detail: detail,
                answer: answer,
              ),
        );
      case LessonStep.result:
        return LessonResultStep(
          key: const ValueKey('step-5'),
          result: session.result!,
          detail: detail,
          onRetry: () =>
              ref.read(lessonSessionProvider(widget.lessonId).notifier).reset(),
          onDone: () => context.pop(),
        );
    }
  }
}
