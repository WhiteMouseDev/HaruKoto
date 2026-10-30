import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../home/providers/study_activity_refresh_provider.dart';

import '../data/models/quiz_question_model.dart';
import '../domain/quiz_resume_exception.dart';
import '../data/models/quiz_result_model.dart';
import 'study_provider.dart';

final quizSessionServiceProvider = Provider<QuizSessionService>((ref) {
  return QuizSessionService(ref);
});

class QuizSessionService {
  const QuizSessionService(this._ref);

  final Ref _ref;

  Future<
      ({
        String sessionId,
        String sessionQuizType,
        List<QuizQuestionModel> questions,
        int currentIndex,
        String? resolvedMode,
      })> initializeSession({
    required String quizType,
    required String jlptLevel,
    required int count,
    String? mode,
    String? resumeSessionId,
    String? stageId,
    String? sourceSessionId,
  }) async {
    final repository = _ref.read(studyRepositoryProvider);

    if (sourceSessionId != null) {
      final data = await repository.startWrongAnswerReview(sourceSessionId);
      final restored =
          _restoreQuestions(data.questions, data.answeredQuestionIds);
      return (
        sessionId: data.sessionId,
        sessionQuizType: data.quizType ?? quizType,
        questions: restored.questions,
        currentIndex: restored.currentIndex,
        resolvedMode: 'wrong_answer_review',
      );
    }

    if (resumeSessionId != null) {
      final data = await repository.resumeQuiz(resumeSessionId);
      final resolvedMode = _resolveMode(
        serverMode: data.mode,
        resumeQuizType: data.quizType,
        fallbackMode: mode,
      );
      _validateResume(data.questions, data.answeredQuestionIds, resolvedMode);
      final restored =
          _restoreQuestions(data.questions, data.answeredQuestionIds);
      return (
        sessionId: data.sessionId,
        sessionQuizType: data.quizType ?? quizType,
        questions: restored.questions,
        currentIndex: restored.currentIndex,
        resolvedMode: resolvedMode,
      );
    }

    if (mode == 'smart') {
      final data = await repository.startSmartQuiz(
        category: quizType,
        jlptLevel: jlptLevel,
        count: count,
      );
      final resolvedMode =
          _resolveMode(serverMode: data.mode, fallbackMode: mode);
      _validateResume(data.questions, const [], resolvedMode, allowEmpty: true);
      return (
        sessionId: data.sessionId,
        sessionQuizType: quizType,
        questions: data.questions,
        currentIndex: 0,
        resolvedMode: resolvedMode,
      );
    }

    // Stage-list categories and the free-quiz picker are presentation inputs.
    // Arrange answers must use the API's sentence category, never vocabulary SRS.
    final startQuizType = mode == 'arrange' ? 'SENTENCE_ARRANGE' : quizType;
    final data = await repository.startQuiz(
      quizType: startQuizType,
      jlptLevel: jlptLevel,
      count: count,
      mode: mode,
      stageId: stageId,
    );
    final resolvedMode =
        _resolveMode(serverMode: data.mode, fallbackMode: mode);
    _validateResume(data.questions, const [], resolvedMode, allowEmpty: true);
    return (
      sessionId: data.sessionId,
      sessionQuizType: startQuizType,
      questions: data.questions,
      currentIndex: 0,
      resolvedMode: resolvedMode,
    );
  }

  Future<void> answerQuestion({
    required String sessionId,
    required String questionId,
    required String selectedOptionId,
    required bool isCorrect,
    required int timeSpentSeconds,
    required String questionType,
  }) {
    return _ref.read(studyRepositoryProvider).answerQuestion(
          sessionId: sessionId,
          questionId: questionId,
          selectedOptionId: selectedOptionId,
          isCorrect: isCorrect,
          timeSpentSeconds: timeSpentSeconds,
          questionType: questionType,
        );
  }

  Future<QuizResultModel> completeQuiz(
    String sessionId, {
    String? stageId,
  }) async {
    final result = await _ref.read(studyRepositoryProvider).completeQuiz(
          sessionId,
          stageId: stageId,
        );
    if (_ref.mounted) _ref.read(studyActivityRefreshProvider).refresh();
    return result;
  }

  String? _resolveMode({
    String? serverMode,
    String? resumeQuizType,
    String? fallbackMode,
  }) {
    const modeMap = {
      'CLOZE': 'cloze',
      'SENTENCE_ARRANGE': 'arrange',
      'TYPING': 'typing',
      'MATCHING': 'matching',
    };
    final mode = serverMode ?? modeMap[resumeQuizType] ?? fallbackMode;
    const knownModes = {
      'normal',
      'matching',
      'arrange',
      'cloze',
      'review',
      'smart',
      'wrong_answer_review',
      'typing',
    };
    if (mode != null && !knownModes.contains(mode)) {
      throw const QuizResumeException();
    }
    return mode;
  }

  void _validateResume(
      List<QuizQuestionModel> questions, List<String> answeredIds, String? mode,
      {bool allowEmpty = false}) {
    if (!allowEmpty && questions.isEmpty) {
      throw const QuizResumeException();
    }
    final ids = questions.map((q) => q.questionId).toSet();
    if (ids.length != questions.length ||
        ids.contains('') ||
        answeredIds.any((id) => !ids.contains(id))) {
      throw const QuizResumeException();
    }
    for (final question in questions) {
      final hasOption = question.options.any((option) =>
          option.id == question.correctOptionId &&
          option.text.trim().isNotEmpty);
      if (mode == 'arrange') {
        if (question.tokens == null ||
            question.tokens!.isEmpty ||
            question.tokens!.any((t) => t.trim().isEmpty) ||
            question.japaneseSentence == null ||
            question.japaneseSentence!.trim().isEmpty) {
          throw const QuizResumeException();
        }
      } else if (mode == 'matching') {
        final hasPair = question.matchingWord?.trim().isNotEmpty == true &&
            question.matchingMeaning?.trim().isNotEmpty == true &&
            question.correctOptionId.isNotEmpty;
        if (!hasPair && !hasOption) throw const QuizResumeException();
      } else if (mode != 'typing' && !hasOption) {
        // In particular, an old VOCABULARY response with empty options must
        // not be mistaken for a usable multiple-choice quiz.
        throw const QuizResumeException(legacy: true);
      }
    }
  }

  ({List<QuizQuestionModel> questions, int currentIndex}) _restoreQuestions(
    List<QuizQuestionModel> questions,
    List<String> answeredQuestionIds,
  ) {
    final answeredIds = answeredQuestionIds.toSet();
    final answered = questions
        .where((question) => answeredIds.contains(question.questionId))
        .toList();
    final remaining = questions
        .where((question) => !answeredIds.contains(question.questionId));
    return (
      questions: [...answered, ...remaining],
      currentIndex: answered.length,
    );
  }
}
