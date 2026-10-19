import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
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
  });

  final String quizType;
  final String jlptLevel;
  final int count;
  final String? mode;
  final String? resumeSessionId;
  final String? stageId;
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

  String get headerCount =>
      questions.isEmpty ? '0/0' : '${currentIndex + 1}/${questions.length}';

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
    );
  }
}

class QuizSessionController extends Notifier<QuizSessionState> {
  final _answerSaves = <String, _PendingQuizAnswer>{};

  @override
  QuizSessionState build() {
    return const QuizSessionState();
  }

  Future<void> initialize(QuizSessionRequest request) async {
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
          );
      state = QuizSessionState(
        loading: false,
        sessionId: data.sessionId,
        sessionQuizType: data.sessionQuizType,
        questions: data.questions,
        currentIndex: data.currentIndex,
        resolvedMode: data.resolvedMode,
      );
    } catch (_) {
      state = QuizSessionState(
        loading: false,
        resolvedMode: request.mode,
        sessionQuizType: request.quizType,
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

    state = state.copyWith(completing: true);
    try {
      await flushPendingAnswers();
      final result = await ref.read(quizSessionServiceProvider).completeQuiz(
            sessionId,
            stageId: stageId,
          );
      state = state.copyWith(completing: false);
      return result;
    } catch (_) {
      state = state.copyWith(completing: false);
      rethrow;
    }
  }

  /// Keep this session alive until every submitted answer is durable. Reuse
  /// the same payload when an exit or completion retries a failed request.
  Future<void> flushPendingAnswers() async {
    for (final answer in _answerSaves.values.where((answer) => answer.failed)) {
      answer.submit();
    }
    await Future.wait(_answerSaves.values.map((answer) => answer.pending));
    if (_answerSaves.values.any((answer) => !answer.saved)) {
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
    final answer = _PendingQuizAnswer(save);
    _answerSaves[questionId] = answer;
    answer.submit();
  }
}

class _PendingQuizAnswer {
  _PendingQuizAnswer(this.save);

  final Future<void> Function() save;
  late Future<void> pending;
  bool saved = false;
  bool failed = false;

  void submit() {
    failed = false;
    pending = save().then((_) {
      saved = true;
    }, onError: (Object error, StackTrace stack) {
      failed = true;
    });
  }
}

final quizSessionProvider =
    NotifierProvider<QuizSessionController, QuizSessionState>(
  QuizSessionController.new,
);
