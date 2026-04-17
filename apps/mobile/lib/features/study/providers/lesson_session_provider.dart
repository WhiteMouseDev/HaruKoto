import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/user_preferences_provider.dart';
import '../../home/providers/home_provider.dart';
import '../data/models/lesson_models.dart';
import '../domain/lesson_flow_policy.dart';
import 'study_provider.dart';

enum LessonStep {
  contextPreview,
  vocabLearning,
  grammarLearning,
  guidedReading,
  recognition,
  matching,
  sentenceReorder,
  result,
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
    this.submissionErrorMessage,
  });

  static const _noResultChange = Object();
  static const _noSubmissionErrorChange = Object();

  final LessonStep step;
  final int recognitionIndex;
  final int reorderIndex;
  final Map<int, Map<String, dynamic>> answers;
  final bool hasRecognitionStep;
  final bool hasReorderStep;
  final LessonSubmitResultModel? result;
  final bool submitting;
  final String? submissionErrorMessage;

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
    Object? submissionErrorMessage = _noSubmissionErrorChange,
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
      submissionErrorMessage:
          identical(submissionErrorMessage, _noSubmissionErrorChange)
              ? this.submissionErrorMessage
              : submissionErrorMessage as String?,
    );
  }
}

class LessonSessionController extends Notifier<LessonSessionState> {
  LessonSessionController(this.lessonId);
  final String lessonId;

  @override
  LessonSessionState build() {
    return const LessonSessionState();
  }

  void goToVocabLearning() {
    state = state.copyWith(step: LessonStep.vocabLearning);
  }

  void goToGrammarLearning() {
    state = state.copyWith(step: LessonStep.grammarLearning);
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
    final practicePlan = buildLessonPracticePlan(detail);

    try {
      await ref.read(studyRepositoryProvider).startLesson(detail.id);
    } catch (_) {
      // Ignore already-started lessons. UI state should still advance.
    }

    state = LessonSessionState(
      step: practicePlan.hasRecognitionStep
          ? LessonStep.recognition
          : LessonStep.matching,
      hasRecognitionStep: practicePlan.hasRecognitionStep,
      hasReorderStep: practicePlan.hasReorderStep,
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
    String? jlptLevel,
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
    required Map<String, dynamic> answer,
    String? jlptLevel,
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
    String? jlptLevel,
  }) async {
    if (state.submitting) return;
    state = state.copyWith(
      submitting: true,
      submissionErrorMessage: null,
    );

    final resolvedJlptLevel =
        jlptLevel ?? ref.read(userPreferencesProvider).jlptLevel;

    try {
      final orderedAnswers = state.answers.keys.toList()..sort();
      final result = await ref.read(studyRepositoryProvider).submitLesson(
        lessonId,
        [
          for (final key in orderedAnswers) state.answers[key]!,
        ],
      );
      ref.invalidate(chaptersProvider(resolvedJlptLevel));
      ref.invalidate(reviewSummaryProvider(resolvedJlptLevel));
      ref.invalidate(dashboardProvider);
      state = state.copyWith(
        step: LessonStep.result,
        result: result,
        submitting: false,
        submissionErrorMessage: null,
      );
    } catch (error) {
      state = state.copyWith(
        submitting: false,
        submissionErrorMessage: '제출 실패: $error',
      );
    }
  }

  void clearSubmissionError() {
    if (state.submissionErrorMessage == null) return;
    state = state.copyWith(submissionErrorMessage: null);
  }

  void reset() {
    state = const LessonSessionState();
  }
}

final lessonSessionProvider = NotifierProvider.autoDispose
    .family<LessonSessionController, LessonSessionState, String>(
  (lessonId) => LessonSessionController(lessonId),
);
