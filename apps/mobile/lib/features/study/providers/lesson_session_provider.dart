import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../home/providers/home_provider.dart';
import '../data/models/lesson_models.dart';
import 'study_provider.dart';

enum LessonStep {
  contextPreview,
  guidedReading,
  recognition,
  matching,
  sentenceReorder,
  result,
}

List<LessonQuestionModel> lessonRecognitionQuestions(
  LessonDetailModel detail,
) {
  return detail.content.questions
      .where((q) => q.type == 'VOCAB_MCQ' || q.type == 'CONTEXT_CLOZE')
      .toList();
}

List<LessonQuestionModel> lessonReorderQuestions(
  LessonDetailModel detail,
) {
  return detail.content.questions
      .where((q) => q.type == 'SENTENCE_REORDER')
      .toList();
}

class LessonSessionState {
  const LessonSessionState({
    this.step = LessonStep.contextPreview,
    this.recognitionIndex = 0,
    this.reorderIndex = 0,
    this.answers = const {},
    this.hasRecognitionStep = false,
    this.hasReorderStep = false,
    this.result,
    this.submitting = false,
  });

  static const _noResultChange = Object();

  final LessonStep step;
  final int recognitionIndex;
  final int reorderIndex;
  final Map<int, Map<String, dynamic>> answers;
  final bool hasRecognitionStep;
  final bool hasReorderStep;
  final LessonSubmitResultModel? result;
  final bool submitting;

  bool get canPop => step == LessonStep.contextPreview;

  bool get showDialogueShortcut =>
      step.index >= LessonStep.recognition.index &&
      step.index <= LessonStep.sentenceReorder.index;

  LessonSessionState copyWith({
    LessonStep? step,
    int? recognitionIndex,
    int? reorderIndex,
    Map<int, Map<String, dynamic>>? answers,
    bool? hasRecognitionStep,
    bool? hasReorderStep,
    Object? result = _noResultChange,
    bool? submitting,
  }) {
    return LessonSessionState(
      step: step ?? this.step,
      recognitionIndex: recognitionIndex ?? this.recognitionIndex,
      reorderIndex: reorderIndex ?? this.reorderIndex,
      answers: answers ?? this.answers,
      hasRecognitionStep: hasRecognitionStep ?? this.hasRecognitionStep,
      hasReorderStep: hasReorderStep ?? this.hasReorderStep,
      result: identical(result, _noResultChange)
          ? this.result
          : result as LessonSubmitResultModel?,
      submitting: submitting ?? this.submitting,
    );
  }
}

class LessonSessionController extends Notifier<LessonSessionState> {
  @override
  LessonSessionState build() {
    return const LessonSessionState();
  }

  void goToGuidedReading() {
    state = state.copyWith(step: LessonStep.guidedReading);
  }

  void goBack() {
    if (state.canPop) return;

    final previousStep = switch (state.step) {
      LessonStep.result => LessonStep.contextPreview,
      LessonStep.matching when !state.hasRecognitionStep =>
        LessonStep.guidedReading,
      _ => LessonStep.values[state.step.index - 1],
    };
    state = state.copyWith(step: previousStep);
  }

  Future<void> startPractice(LessonDetailModel detail) async {
    final hasRecognitionStep = lessonRecognitionQuestions(detail).isNotEmpty;
    final hasReorderStep = lessonReorderQuestions(detail).isNotEmpty;

    try {
      await ref.read(studyRepositoryProvider).startLesson(detail.id);
    } catch (_) {
      // Ignore already-started lessons. UI state should still advance.
    }

    state = LessonSessionState(
      step: hasRecognitionStep ? LessonStep.recognition : LessonStep.matching,
      hasRecognitionStep: hasRecognitionStep,
      hasReorderStep: hasReorderStep,
    );
  }

  void skipRecognition() {
    state = state.copyWith(step: LessonStep.matching);
  }

  void answerRecognition(
    LessonDetailModel detail,
    Map<String, dynamic> answer,
  ) {
    final recognitionQuestions = lessonRecognitionQuestions(detail);
    final answers = Map<int, Map<String, dynamic>>.from(state.answers);
    answers[answer['order'] as int] = Map<String, dynamic>.from(answer);

    if (state.recognitionIndex < recognitionQuestions.length - 1) {
      state = state.copyWith(
        answers: answers,
        recognitionIndex: state.recognitionIndex + 1,
      );
      return;
    }

    state = state.copyWith(
      answers: answers,
      step: LessonStep.matching,
    );
  }

  Future<void> completeMatching({
    required LessonDetailModel detail,
    required String jlptLevel,
  }) async {
    if (!state.hasReorderStep) {
      await submitAnswers(
        lessonId: detail.id,
        jlptLevel: jlptLevel,
      );
      return;
    }

    state = state.copyWith(step: LessonStep.sentenceReorder);
  }

  Future<void> answerReorder({
    required LessonDetailModel detail,
    required String jlptLevel,
    required Map<String, dynamic> answer,
  }) async {
    final reorderQuestions = lessonReorderQuestions(detail);
    final answers = Map<int, Map<String, dynamic>>.from(state.answers);
    answers[answer['order'] as int] = Map<String, dynamic>.from(answer);

    if (state.reorderIndex < reorderQuestions.length - 1) {
      state = state.copyWith(
        answers: answers,
        reorderIndex: state.reorderIndex + 1,
      );
      return;
    }

    state = state.copyWith(answers: answers);
    await submitAnswers(
      lessonId: detail.id,
      jlptLevel: jlptLevel,
    );
  }

  Future<void> submitAnswers({
    required String lessonId,
    required String jlptLevel,
  }) async {
    if (state.submitting) return;
    state = state.copyWith(submitting: true);

    try {
      final orderedAnswers = state.answers.keys.toList()..sort();
      final result = await ref.read(studyRepositoryProvider).submitLesson(
        lessonId,
        [
          for (final key in orderedAnswers) state.answers[key]!,
        ],
      );
      ref.invalidate(chaptersProvider(jlptLevel));
      ref.invalidate(reviewSummaryProvider(jlptLevel));
      ref.invalidate(dashboardProvider);
      state = state.copyWith(
        step: LessonStep.result,
        result: result,
        submitting: false,
      );
    } catch (_) {
      state = state.copyWith(submitting: false);
      rethrow;
    }
  }

  void reset() {
    state = const LessonSessionState();
  }
}

final lessonSessionProvider =
    NotifierProvider<LessonSessionController, LessonSessionState>(
  LessonSessionController.new,
);
