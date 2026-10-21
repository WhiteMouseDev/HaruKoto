import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    required this.onExit,
  });

  final String lessonId;
  final LessonDetailModel detail;
  final LessonSessionState session;
  final int totalSteps;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionNotifier =
        ref.read(lessonSessionProvider(lessonId).notifier).actions;

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
          initialIndex: session.vocabIndex,
          onIndexChanged: sessionNotifier.setVocabIndex,
          onNext: detail.grammarItems.isNotEmpty
              ? sessionNotifier.goToGrammarLearning
              : sessionNotifier.goToGuidedReading,
        );
      case LessonStep.grammarLearning:
        return LessonGrammarLearningStep(
          key: const ValueKey('step-grammar'),
          grammarItems: detail.grammarItems,
          initialIndex: session.grammarIndex,
          onIndexChanged: sessionNotifier.setGrammarIndex,
          onBackToPrev: sessionNotifier.goBack,
          onNext: sessionNotifier.goToGuidedReading,
        );
      case LessonStep.guidedReading:
        return LessonGuidedReadingStep(
          key: const ValueKey('step-1'),
          detail: detail,
          onNext: session.starting
              ? null
              : () => unawaited(sessionNotifier.startPractice(detail)),
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
          initialSelection: session.recognitionSelection ??
              session.answers[recognitionQuestions[session.recognitionIndex]
                  .order]?['selectedAnswer'] as String?,
          optionOrder: session.layout.recognitionOptions[
              recognitionQuestions[session.recognitionIndex].order],
          onSelectionChanged: sessionNotifier.selectRecognition,
          onAnswer: (answer) =>
              sessionNotifier.answerRecognition(detail, answer),
        );
      case LessonStep.matching:
        return LessonMatchingGameStep(
          key: const ValueKey('step-3'),
          vocabItems: detail.vocabItems,
          pairOrder: session.layout.matchingVocabIds,
          rightOrder: session.layout.matchingRightIndices,
          initialMatched: session.matchingMatched,
          initialLeft: session.matchingLeft,
          initialRight: session.matchingRight,
          autoAdvance: !session.restored,
          onProgress: (matched, left, right) => sessionNotifier.updateMatching(
              matched: matched, left: left, right: right),
          onComplete: () =>
              unawaited(sessionNotifier.completeMatching(detail: detail)),
        );
      case LessonStep.sentenceReorder:
        final reorderQuestions = lessonReorderQuestions(detail);
        if (reorderQuestions.isEmpty) {
          return Center(
              child: FilledButton(
            onPressed: () =>
                unawaited(sessionNotifier.submitAnswers(lessonId: detail.id)),
            child: const Text('답안 제출하기'),
          ));
        }

        return LessonSentenceReorderStep(
          key: ValueKey('step-4-${session.reorderIndex}'),
          questions: reorderQuestions,
          currentIndex: session.reorderIndex,
          totalSteps: totalSteps,
          vocabItems: detail.vocabItems,
          shuffledBank: session.layout
              .reorderBanks[reorderQuestions[session.reorderIndex].order],
          initialSelected: session.reorderSelected,
          initialAvailable: session.reorderAvailable,
          onDraftChanged: (selected, available) => sessionNotifier
              .updateReorder(selected: selected, available: available),
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
          onRetry: () => unawaited(sessionNotifier.reset()),
          onDone: () {
            if (sessionNotifier.isCurrent) onExit();
          },
        );
    }
  }
}
