import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../domain/quiz_resume_exception.dart';
import '../data/models/quiz_question_model.dart';
import '../data/models/quiz_result_model.dart';
import 'quiz_session_service.dart';

class QuizSessionRequest {
  const QuizSessionRequest({
    required this.quizType,
    required this.jlptLevel,
    required this.count,
    this.mode,
    this.resumeSessionId,
    this.stageId,
    this.sourceSessionId,
  });

  final String quizType;
  final String jlptLevel;
  final int count;
  final String? mode;
  final String? resumeSessionId;
  final String? stageId;
  final String? sourceSessionId;
}

class QuizSessionState {
  const QuizSessionState({
    this.loading = true,
    this.sessionId,
    this.sessionQuizType,
    this.questions = const [],
    this.currentIndex = 0,
    this.selectedOptionId,
    this.answered = false,
    this.isCorrect = false,
    this.streak = 0,
    this.resolvedMode,
    this.timeSpent = 0,
    this.completing = false,
    this.completionError,
    this.loadError,
    this.loadErrorCanRetry = true,
    this.savedSpecialQuestionIds = const {},
  });

  static const _unset = Object();

  final bool loading;
  final String? sessionId;
  final String? sessionQuizType;
  final List<QuizQuestionModel> questions;
  final int currentIndex;
  final String? selectedOptionId;
  final bool answered;
  final bool isCorrect;
  final int streak;
  final String? resolvedMode;
  final int timeSpent;
  final bool completing;
  final ApiException? completionError;
  final String? loadError;
  final bool loadErrorCanRetry;
  final Set<String> savedSpecialQuestionIds;

  int get savedSpecialCount => currentIndex + savedSpecialQuestionIds.length;

  QuizQuestionModel? get currentQuestion =>
      currentIndex < questions.length ? questions[currentIndex] : null;

  List<QuizQuestionModel> get unansweredQuestions =>
      currentIndex < questions.length
          ? questions.sublist(currentIndex)
          : const <QuizQuestionModel>[];

  bool get isLastQuestion =>
      questions.isNotEmpty && currentIndex + 1 >= questions.length;

  double get progress =>
      questions.isEmpty ? 0 : (currentIndex + 1) / questions.length;

  bool get isSpecialMode =>
      resolvedMode == 'matching' ||
      resolvedMode == 'cloze' ||
      resolvedMode == 'arrange' ||
      resolvedMode == 'typing';

  String get headerCount => isSpecialMode && questions.isNotEmpty
      ? '$savedSpecialCount/${questions.length} 저장'
      : questions.isEmpty
          ? '0/0'
          : '${currentQuestion == null ? questions.length : currentIndex + 1}/${questions.length}';

  String effectiveQuizType(String fallback) => sessionQuizType ?? fallback;

  String displayQuizType(String fallback) {
    const specialTypes = {
      'MATCHING',
      'CLOZE',
      'SENTENCE_ARRANGE',
      'TYPING',
    };
    if (specialTypes.contains(sessionQuizType)) {
      return fallback;
    }
    return sessionQuizType ?? fallback;
  }

  QuizSessionState copyWith({
    bool? loading,
    Object? sessionId = _unset,
    Object? sessionQuizType = _unset,
    List<QuizQuestionModel>? questions,
    int? currentIndex,
    Object? selectedOptionId = _unset,
    bool? answered,
    bool? isCorrect,
    int? streak,
    Object? resolvedMode = _unset,
    int? timeSpent,
    bool? completing,
    Object? completionError = _unset,
    Object? loadError = _unset,
    bool? loadErrorCanRetry,
    Set<String>? savedSpecialQuestionIds,
  }) {
    return QuizSessionState(
      loading: loading ?? this.loading,
      sessionId:
          identical(sessionId, _unset) ? this.sessionId : sessionId as String?,
      sessionQuizType: identical(sessionQuizType, _unset)
          ? this.sessionQuizType
          : sessionQuizType as String?,
      questions: questions ?? this.questions,
      currentIndex: currentIndex ?? this.currentIndex,
      selectedOptionId: identical(selectedOptionId, _unset)
          ? this.selectedOptionId
          : selectedOptionId as String?,
      answered: answered ?? this.answered,
      isCorrect: isCorrect ?? this.isCorrect,
      streak: streak ?? this.streak,
      resolvedMode: identical(resolvedMode, _unset)
          ? this.resolvedMode
          : resolvedMode as String?,
      timeSpent: timeSpent ?? this.timeSpent,
      completing: completing ?? this.completing,
      completionError: identical(completionError, _unset)
          ? this.completionError
          : completionError as ApiException?,
      loadError:
          identical(loadError, _unset) ? this.loadError : loadError as String?,
      loadErrorCanRetry: loadErrorCanRetry ?? this.loadErrorCanRetry,
      savedSpecialQuestionIds:
          savedSpecialQuestionIds ?? this.savedSpecialQuestionIds,
    );
  }
}

class QuizSessionController extends Notifier<QuizSessionState> {
  final _answerSaves = <String, _PendingQuizAnswer>{};
  int _initializationSerial = 0;

  @override
  QuizSessionState build() {
    ref.onDispose(() => _initializationSerial++);
    return const QuizSessionState();
  }

  Future<void> initialize(QuizSessionRequest request) async {
    final requestId = ++_initializationSerial;
    _answerSaves.clear();
    state = QuizSessionState(
      loading: true,
      resolvedMode: request.mode,
      sessionQuizType: request.quizType,
    );

    try {
      final data = await ref.read(quizSessionServiceProvider).initializeSession(
            quizType: request.quizType,
            jlptLevel: request.jlptLevel,
            count: request.count,
            mode: request.mode,
            resumeSessionId: request.resumeSessionId,
            stageId: request.stageId,
            sourceSessionId: request.sourceSessionId,
          );
      if (!ref.mounted || requestId != _initializationSerial) return;
      state = QuizSessionState(
        loading: false,
        sessionId: data.sessionId,
        sessionQuizType: data.sessionQuizType,
        questions: data.questions,
        currentIndex: data.currentIndex,
        resolvedMode: data.resolvedMode,
      );
    } catch (error) {
      if (!ref.mounted || requestId != _initializationSerial) return;
      final cause = error is DioException ? error.error : error;
      state = QuizSessionState(
        loading: false,
        resolvedMode: request.mode,
        sessionQuizType: request.quizType,
        loadError: cause is ApiException
            ? cause.userMessage
            : const ApiException(message: '잠시 후 다시 시도해 주세요.').userMessage,
        loadErrorCanRetry: cause is! QuizResumeException,
      );
    }
  }

  void incrementTimer() {
    state = state.copyWith(timeSpent: state.timeSpent + 1);
  }

  void resetTimer() {
    state = state.copyWith(timeSpent: 0);
  }

  bool? answerCurrentQuestion({
    required String optionId,
    required String questionType,
  }) {
    final question = state.currentQuestion;
    final sessionId = state.sessionId;
    if (state.answered || question == null || sessionId == null) {
      return null;
    }

    final elapsed = state.timeSpent;
    final isCorrect = optionId == question.correctOptionId;
    final nextStreak = isCorrect ? state.streak + 1 : 0;

    state = state.copyWith(
      selectedOptionId: optionId,
      answered: true,
      isCorrect: isCorrect,
      streak: nextStreak,
    );

    _saveAnswer(
      question.questionId,
      () => ref.read(quizSessionServiceProvider).answerQuestion(
            sessionId: sessionId,
            questionId: question.questionId,
            selectedOptionId: optionId,
            isCorrect: isCorrect,
            timeSpentSeconds: elapsed,
            questionType: questionType,
          ),
    );

    return isCorrect;
  }

  void advanceToNextQuestion() {
    if (state.isLastQuestion) return;
    state = state.copyWith(
      currentIndex: state.currentIndex + 1,
      selectedOptionId: null,
      answered: false,
      isCorrect: false,
      timeSpent: 0,
    );
  }

  void submitSpecialAnswer({
    required String questionId,
    required bool isCorrect,
    required String questionType,
    String? optionId,
  }) {
    final sessionId = state.sessionId;
    if (sessionId == null) return;

    if (state.questions
        .take(state.currentIndex)
        .any((q) => q.questionId == questionId)) {
      return;
    }

    final question =
        state.questions.firstWhere((q) => q.questionId == questionId);
    _saveAnswer(
      questionId,
      () => ref.read(quizSessionServiceProvider).answerQuestion(
            sessionId: sessionId,
            questionId: questionId,
            selectedOptionId:
                optionId ?? (isCorrect ? question.correctOptionId : 'wrong'),
            isCorrect: isCorrect,
            timeSpentSeconds: 0,
            questionType: questionType,
          ),
    );
  }

  Future<QuizResultModel?> completeQuiz({String? stageId}) async {
    final sessionId = state.sessionId;
    if (sessionId == null || state.completing) {
      return null;
    }

    final revision = _initializationSerial;
    state = state.copyWith(completing: true, completionError: null);
    try {
      await flushPendingAnswers();
      if (!ref.mounted || revision != _initializationSerial) return null;
      final result = await ref.read(quizSessionServiceProvider).completeQuiz(
            sessionId,
            stageId: stageId,
          );
      if (!ref.mounted || revision != _initializationSerial) return null;
      state = state.copyWith(completing: false);
      return result;
    } catch (error) {
      if (!ref.mounted || revision != _initializationSerial) return null;
      state = state.copyWith(
        completing: false,
        completionError: error is ApiException && error.statusCode == 409
            ? const ApiException(message: '답안 저장을 확인하지 못했어요. 다시 시도해주세요.')
            : error is ApiException
                ? error
                : const ApiException(message: '퀴즈 결과를 저장하지 못했어요. 다시 시도해주세요.'),
      );
      rethrow;
    }
  }

  /// Keep this session alive until every submitted answer is durable. Reuse
  /// the same payload when an exit or completion retries a failed request.
  Future<void> flushPendingAnswers() async {
    final revision = _initializationSerial;
    final answers = _answerSaves.values.toList();
    for (final answer in answers.where((answer) => answer.failed)) {
      answer.submit();
    }
    await Future.wait(answers.map((answer) => answer.pending));
    if (!ref.mounted ||
        revision != _initializationSerial ||
        answers.any((answer) => !answer.saved)) {
      throw const ApiException(
        message: '답안을 저장하지 못했어요. 다시 시도해주세요.',
        errorCode: 'QUIZ_ANSWER_SAVE_FAILED',
      );
    }
  }

  void _saveAnswer(String questionId, Future<void> Function() save) {
    // Matching can report a corrected pair after its first scored attempt.
    // The server keeps that first answer immutable, including on retries.
    if (_answerSaves.containsKey(questionId)) return;
    final revision = _initializationSerial;
    final answer = _PendingQuizAnswer(save, () {
      if (!ref.mounted || revision != _initializationSerial) return;
      state = state.copyWith(savedSpecialQuestionIds: {
        ...state.savedSpecialQuestionIds,
        questionId,
      });
    });
    _answerSaves[questionId] = answer;
    answer.submit();
  }
}

class _PendingQuizAnswer {
  _PendingQuizAnswer(this.save, this.onSaved);

  final Future<void> Function() save;
  final void Function() onSaved;
  late Future<void> pending;
  bool saved = false;
  bool failed = false;

  void submit() {
    failed = false;
    pending = save().then((_) {
      saved = true;
      onSaved();
    }, onError: (Object error, StackTrace stack) {
      failed = true;
    });
  }
}

final quizSessionProvider =
    NotifierProvider<QuizSessionController, QuizSessionState>(
  QuizSessionController.new,
);
