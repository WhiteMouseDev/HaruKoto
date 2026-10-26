import '../data/models/lesson_models.dart';
import 'lesson_practice_layout.dart';

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
    this.vocabIndex = 0,
    this.grammarIndex = 0,
    this.recognitionIndex = 0,
    this.reorderIndex = 0,
    this.answers = const {},
    this.hasRecognitionStep = false,
    this.hasReorderStep = false,
    this.result,
    this.submitting = false,
    this.starting = false,
    this.practiceStarted = false,
    this.submissionPending = false,
    this.seed = 1,
    this.layout = const LessonPracticeLayout(),
    this.recognitionSelection,
    this.matchingMatched = const {},
    this.matchingLeft,
    this.matchingRight,
    this.reorderSelected = const [],
    this.reorderAvailable,
    this.storageError = false,
    this.notice,
    this.serverRecorded = false,
    this.serverProgress,
    this.restored = false,
    this.startErrorMessage,
    this.submissionErrorMessage,
  });

  static const _noResultChange = Object();
  static const _noStartErrorChange = Object();
  static const _noSubmissionErrorChange = Object();

  final LessonStep step;
  final int vocabIndex;
  final int grammarIndex;
  final int recognitionIndex;
  final int reorderIndex;
  final Map<int, Map<String, dynamic>> answers;
  final bool hasRecognitionStep;
  final bool hasReorderStep;
  final LessonSubmitResultModel? result;
  final bool submitting;
  final bool starting;
  final bool practiceStarted;
  final bool submissionPending;
  final int seed;
  final LessonPracticeLayout layout;
  final String? recognitionSelection;
  final Set<int> matchingMatched;
  final int? matchingLeft;
  final int? matchingRight;
  final List<String> reorderSelected;
  final List<String>? reorderAvailable;
  final bool storageError;
  final String? notice;
  final bool serverRecorded;
  final LessonProgressModel? serverProgress;
  final bool restored;
  final String? startErrorMessage;
  final String? submissionErrorMessage;

  bool get canPop => step == LessonStep.contextPreview;

  bool get showDialogueShortcut =>
      step.index >= LessonStep.recognition.index &&
      step.index <= LessonStep.sentenceReorder.index;

  LessonSessionState copyWith({
    LessonStep? step,
    int? vocabIndex,
    int? grammarIndex,
    int? recognitionIndex,
    int? reorderIndex,
    Map<int, Map<String, dynamic>>? answers,
    bool? hasRecognitionStep,
    bool? hasReorderStep,
    Object? result = _noResultChange,
    bool? submitting,
    bool? starting,
    bool? practiceStarted,
    bool? submissionPending,
    int? seed,
    LessonPracticeLayout? layout,
    Object? recognitionSelection = _noResultChange,
    Set<int>? matchingMatched,
    Object? matchingLeft = _noResultChange,
    Object? matchingRight = _noResultChange,
    List<String>? reorderSelected,
    Object? reorderAvailable = _noResultChange,
    bool? storageError,
    Object? notice = _noResultChange,
    bool? serverRecorded,
    LessonProgressModel? serverProgress,
    bool? restored,
    Object? startErrorMessage = _noStartErrorChange,
    Object? submissionErrorMessage = _noSubmissionErrorChange,
  }) {
    return LessonSessionState(
      step: step ?? this.step,
      vocabIndex: vocabIndex ?? this.vocabIndex,
      grammarIndex: grammarIndex ?? this.grammarIndex,
      recognitionIndex: recognitionIndex ?? this.recognitionIndex,
      reorderIndex: reorderIndex ?? this.reorderIndex,
      answers: answers ?? this.answers,
      hasRecognitionStep: hasRecognitionStep ?? this.hasRecognitionStep,
      hasReorderStep: hasReorderStep ?? this.hasReorderStep,
      result: identical(result, _noResultChange)
          ? this.result
          : result as LessonSubmitResultModel?,
      submitting: submitting ?? this.submitting,
      starting: starting ?? this.starting,
      practiceStarted: practiceStarted ?? this.practiceStarted,
      submissionPending: submissionPending ?? this.submissionPending,
      seed: seed ?? this.seed,
      layout: layout ?? this.layout,
      recognitionSelection: identical(recognitionSelection, _noResultChange)
          ? this.recognitionSelection
          : recognitionSelection as String?,
      matchingMatched: matchingMatched ?? this.matchingMatched,
      matchingLeft: identical(matchingLeft, _noResultChange)
          ? this.matchingLeft
          : matchingLeft as int?,
      matchingRight: identical(matchingRight, _noResultChange)
          ? this.matchingRight
          : matchingRight as int?,
      reorderSelected: reorderSelected ?? this.reorderSelected,
      reorderAvailable: identical(reorderAvailable, _noResultChange)
          ? this.reorderAvailable
          : reorderAvailable as List<String>?,
      storageError: storageError ?? this.storageError,
      notice:
          identical(notice, _noResultChange) ? this.notice : notice as String?,
      serverRecorded: serverRecorded ?? this.serverRecorded,
      serverProgress: serverProgress ?? this.serverProgress,
      restored: restored ?? this.restored,
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
