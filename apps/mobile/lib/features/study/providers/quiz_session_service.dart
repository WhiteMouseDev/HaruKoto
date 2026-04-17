import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/quiz_question_model.dart';
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
  }) async {
    final repository = _ref.read(studyRepositoryProvider);

    if (resumeSessionId != null) {
      final data = await repository.resumeQuiz(resumeSessionId);
      return (
        sessionId: data.sessionId,
        sessionQuizType: data.quizType ?? quizType,
        questions: data.questions,
        currentIndex: data.answeredQuestionIds.length,
        resolvedMode: _resolveMode(
          resumeQuizType: data.quizType,
          fallbackMode: mode,
        ),
      );
    }

    if (mode == 'smart') {
      final data = await repository.startSmartQuiz(
        category: quizType,
        jlptLevel: jlptLevel,
        count: count,
      );
      return (
        sessionId: data.sessionId,
        sessionQuizType: quizType,
        questions: data.questions,
        currentIndex: 0,
        resolvedMode: mode,
      );
    }

    final data = await repository.startQuiz(
      quizType: quizType,
      jlptLevel: jlptLevel,
      count: count,
      mode: mode,
      stageId: stageId,
    );
    return (
      sessionId: data.sessionId,
      sessionQuizType: quizType,
      questions: data.questions,
      currentIndex: 0,
      resolvedMode: mode,
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
  }) {
    return _ref.read(studyRepositoryProvider).completeQuiz(
          sessionId,
          stageId: stageId,
        );
  }

  String? _resolveMode({
    required String? resumeQuizType,
    required String? fallbackMode,
  }) {
    const modeMap = {
      'CLOZE': 'cloze',
      'SENTENCE_ARRANGE': 'arrange',
      'TYPING': 'typing',
      'MATCHING': 'matching',
    };
    return modeMap[resumeQuizType] ?? fallbackMode;
  }
}
