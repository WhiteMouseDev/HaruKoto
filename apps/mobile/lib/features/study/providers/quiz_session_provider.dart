import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  @override
  QuizSessionState build() {
    return const QuizSessionState();
  }

  Future<void> initialize(QuizSessionRequest request) async {
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

    unawaited(
      ref.read(quizSessionServiceProvider).answerQuestion(
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
    unawaited(
      ref.read(quizSessionServiceProvider).answerQuestion(
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
}

final quizSessionProvider =
    NotifierProvider<QuizSessionController, QuizSessionState>(
  QuizSessionController.new,
);
