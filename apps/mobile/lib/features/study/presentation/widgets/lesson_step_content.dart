import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/lesson_models.dart';
import '../../domain/lesson_flow_policy.dart';
import '../../providers/lesson_session_provider.dart';
import 'lesson_learning_steps.dart';
import 'lesson_intro_steps.dart';
import 'lesson_practice_steps.dart';
import 'lesson_result_step.dart';

class LessonStepContent extends ConsumerWidget {
  const LessonStepContent({
    super.key,
    required this.lessonId,
    required this.detail,
    required this.session,
    required this.totalSteps,
  });

  final String lessonId;
  final LessonDetailModel detail;
  final LessonSessionState session;
  final int totalSteps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionNotifier = ref.read(lessonSessionProvider(lessonId).notifier);

    switch (session.step) {
      case LessonStep.contextPreview:
        return LessonContextPreviewStep(
          key: const ValueKey('step-0'),
          detail: detail,
          onNext: sessionNotifier.goToVocabLearning,
        );
      case LessonStep.vocabLearning:
        return LessonVocabLearningStep(
          key: const ValueKey('step-vocab'),
          vocabItems: detail.vocabItems,
          onBackToPrev: sessionNotifier.goBack,
          onNext: detail.grammarItems.isNotEmpty
              ? sessionNotifier.goToGrammarLearning
              : sessionNotifier.goToGuidedReading,
        );
      case LessonStep.grammarLearning:
        return LessonGrammarLearningStep(
          key: const ValueKey('step-grammar'),
          grammarItems: detail.grammarItems,
          onBackToPrev: sessionNotifier.goBack,
          onNext: sessionNotifier.goToGuidedReading,
        );
      case LessonStep.guidedReading:
        return LessonGuidedReadingStep(
          key: const ValueKey('step-1'),
          detail: detail,
          onNext: () => unawaited(sessionNotifier.startPractice(detail)),
        );
      case LessonStep.recognition:
        final recognitionQuestions = lessonRecognitionQuestions(detail);
        if (recognitionQuestions.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            sessionNotifier.skipRecognition();
          });
          return const SizedBox.shrink(key: ValueKey('step-2-skip'));
        }

        return LessonRecognitionCheckStep(
          key: ValueKey('step-2-${session.recognitionIndex}'),
          questions: recognitionQuestions,
          currentIndex: session.recognitionIndex,
          totalSteps: totalSteps,
          onAnswer: (answer) =>
              sessionNotifier.answerRecognition(detail, answer),
        );
      case LessonStep.matching:
        return LessonMatchingGameStep(
          key: const ValueKey('step-3'),
          vocabItems: detail.vocabItems,
          onComplete: () =>
              unawaited(sessionNotifier.completeMatching(detail: detail)),
        );
      case LessonStep.sentenceReorder:
        final reorderQuestions = lessonReorderQuestions(detail);
        if (reorderQuestions.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            unawaited(sessionNotifier.submitAnswers(lessonId: detail.id));
          });
          return const SizedBox.shrink(key: ValueKey('step-4-skip'));
        }

        return LessonSentenceReorderStep(
          key: ValueKey('step-4-${session.reorderIndex}'),
          questions: reorderQuestions,
          currentIndex: session.reorderIndex,
          totalSteps: totalSteps,
          vocabItems: detail.vocabItems,
          onAnswer: (answer) => sessionNotifier.answerReorder(
            detail: detail,
            answer: answer,
          ),
        );
      case LessonStep.result:
        return LessonResultStep(
          key: const ValueKey('step-5'),
          result: session.result!,
          detail: detail,
          onRetry: sessionNotifier.reset,
          onDone: () => context.pop(),
        );
    }
  }
}
