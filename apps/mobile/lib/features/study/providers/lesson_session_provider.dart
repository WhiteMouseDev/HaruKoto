import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/lesson_models.dart';
import '../domain/lesson_flow_policy.dart';
import 'lesson_pilot_telemetry_provider.dart';
import 'lesson_session_service.dart';

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
    this.startErrorMessage,
    this.submissionErrorMessage,
  });

  static const _noResultChange = Object();
  static const _noStartErrorChange = Object();
  static const _noSubmissionErrorChange = Object();

  final LessonStep step;
  final int recognitionIndex;
  final int reorderIndex;
  final Map<int, Map<String, dynamic>> answers;
  final bool hasRecognitionStep;
  final bool hasReorderStep;
  final LessonSubmitResultModel? result;
  final bool submitting;
  final String? startErrorMessage;
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
    Object? startErrorMessage = _noStartErrorChange,
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
      startErrorMessage: identical(startErrorMessage, _noStartErrorChange)
          ? this.startErrorMessage
          : startErrorMessage as String?,
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
    _trackStepCompleted(state.step);
    state = state.copyWith(step: LessonStep.vocabLearning);
  }

  void goToGrammarLearning() {
    _trackStepCompleted(state.step);
    state = state.copyWith(step: LessonStep.grammarLearning);
  }

  void goToGuidedReading() {
    _trackStepCompleted(state.step);
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
      await ref.read(lessonSessionServiceProvider).startLesson(detail.id);
    } catch (error) {
      state = state.copyWith(
        startErrorMessage: '레슨 시작 실패: $error',
      );
      return;
    }

    ref.read(lessonPilotTelemetryProvider).trackLessonStarted(
          lessonId: detail.id,
          lessonNo: detail.lessonNo,
          chapterLessonNo: detail.chapterLessonNo,
          hasRecognitionStep: practicePlan.hasRecognitionStep,
          hasReorderStep: practicePlan.hasReorderStep,
          recognitionQuestionCount: practicePlan.recognitionQuestions.length,
          reorderQuestionCount: practicePlan.reorderQuestions.length,
        );

    state = LessonSessionState(
      step: practicePlan.hasRecognitionStep
          ? LessonStep.recognition
          : LessonStep.matching,
      hasRecognitionStep: practicePlan.hasRecognitionStep,
      hasReorderStep: practicePlan.hasReorderStep,
    );
  }

  void skipRecognition() {
    _trackStepCompleted(LessonStep.recognition, skipped: true);
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

    _trackStepCompleted(LessonStep.recognition);
    state = state.copyWith(
      answers: answers,
      step: LessonStep.matching,
    );
  }

  Future<void> completeMatching({
    required LessonDetailModel detail,
    String? jlptLevel,
  }) async {
    _trackStepCompleted(LessonStep.matching);

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

    _trackStepCompleted(LessonStep.sentenceReorder);
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
    final orderedAnswers = state.answers.keys.toList()..sort();
    state = state.copyWith(
      submitting: true,
      submissionErrorMessage: null,
    );

    try {
      final result = await ref.read(lessonSessionServiceProvider).submitLesson(
        lessonId: lessonId,
        jlptLevel: jlptLevel,
        answers: [
          for (final key in orderedAnswers) state.answers[key]!,
        ],
      );
      state = state.copyWith(
        step: LessonStep.result,
        result: result,
        submitting: false,
        submissionErrorMessage: null,
      );
      ref.read(lessonPilotTelemetryProvider).trackLessonSubmitted(
            lessonId: lessonId,
            outcome: 'success',
            answerCount: orderedAnswers.length,
            status: result.status,
            scoreCorrect: result.scoreCorrect,
            scoreTotal: result.scoreTotal,
            srsItemsRegistered: result.srsItemsRegistered,
          );
      if (result.status == 'COMPLETED') {
        ref.read(lessonPilotTelemetryProvider).trackLessonCompleted(
              lessonId: lessonId,
              scoreCorrect: result.scoreCorrect,
              scoreTotal: result.scoreTotal,
              srsItemsRegistered: result.srsItemsRegistered,
            );
      }
    } catch (error) {
      ref.read(lessonPilotTelemetryProvider).trackLessonSubmitted(
            lessonId: lessonId,
            outcome: 'failure',
            answerCount: orderedAnswers.length,
            errorType: error.runtimeType.toString(),
          );
      state = state.copyWith(
        submitting: false,
        submissionErrorMessage: '제출 실패: $error',
      );
    }
  }

  void clearStartError() {
    if (state.startErrorMessage == null) return;
    state = state.copyWith(startErrorMessage: null);
  }

  void clearSubmissionError() {
    if (state.submissionErrorMessage == null) return;
    state = state.copyWith(submissionErrorMessage: null);
  }

  void reset() {
    ref.read(lessonPilotTelemetryProvider).trackLessonRetryClicked(
          lessonId: lessonId,
        );
    state = const LessonSessionState();
  }

  void _trackStepCompleted(LessonStep step, {bool skipped = false}) {
    if (step == LessonStep.result) return;
    ref.read(lessonPilotTelemetryProvider).trackLessonStepCompleted(
          lessonId: lessonId,
          step: step.name,
          skipped: skipped,
        );
  }
}

final lessonSessionProvider = NotifierProvider.autoDispose
    .family<LessonSessionController, LessonSessionState, String>(
  (lessonId) => LessonSessionController(lessonId),
);
