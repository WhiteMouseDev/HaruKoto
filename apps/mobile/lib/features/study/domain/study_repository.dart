import '../data/models/lesson_models.dart';
import '../data/models/quiz_question_model.dart';
import '../data/models/quiz_result_model.dart';
import '../data/models/quiz_session_model.dart';
import '../data/models/recommendation_model.dart';
import '../data/models/review_summary_model.dart';
import '../data/models/smart_preview_model.dart';
import '../data/models/stage_model.dart';
import '../data/models/word_entry_model.dart';
import '../data/models/wordbook_entry_model.dart';

abstract class StudyRepository {
  Future<List<StageModel>> fetchStages(String category, String jlptLevel);

  Future<IncompleteSessionModel?> fetchIncompleteQuiz();

  Future<StudyStatsModel> fetchQuizStats(String level, String type);

  Future<RecommendationModel> fetchRecommendations();

  Future<SmartPreviewModel> fetchSmartPreview({
    String category = 'VOCABULARY',
    String jlptLevel = 'N5',
  });

  Future<({String sessionId, List<QuizQuestionModel> questions})>
      startSmartQuiz({
    String category = 'VOCABULARY',
    String jlptLevel = 'N5',
    int count = 20,
  });

  Future<({String sessionId, List<QuizQuestionModel> questions})> startQuiz({
    required String quizType,
    required String jlptLevel,
    required int count,
    String? mode,
    String? stageId,
  });

  Future<
      ({
        String sessionId,
        List<QuizQuestionModel> questions,
        List<String> answeredQuestionIds,
        int correctCount,
        String? quizType,
      })> resumeQuiz(String sessionId);

  Future<void> answerQuestion({
    required String sessionId,
    required String questionId,
    required String selectedOptionId,
    required bool isCorrect,
    required int timeSpentSeconds,
    required String questionType,
  });

  Future<QuizResultModel> completeQuiz(
    String sessionId, {
    String? stageId,
  });

  Future<List<WrongAnswerModel>> fetchWrongAnswersBySession(String sessionId);

  Future<
      ({
        List<WrongEntryModel> entries,
        int total,
        int totalPages,
        WrongAnswersSummary summary,
      })> fetchWrongAnswers({
    int page = 1,
    String sort = 'most-wrong',
    int limit = 20,
  });

  Future<
      ({
        List<LearnedWordModel> entries,
        int total,
        int totalPages,
        LearnedWordsSummary summary,
      })> fetchLearnedWords({
    int page = 1,
    String sort = 'recent',
    String search = '',
    String filter = 'ALL',
    int limit = 20,
  });

  Future<
      ({
        List<WordbookEntryModel> entries,
        int total,
        int totalPages,
      })> fetchWordbook({
    int page = 1,
    String sort = 'recent',
    String search = '',
    String filter = 'ALL',
    int limit = 20,
  });

  Future<void> addWord({
    required String word,
    required String reading,
    required String meaningKo,
    String source = 'MANUAL',
    String? note,
  });

  Future<void> deleteWord(String id);

  Future<String> fetchTtsUrl(String vocabId);

  Future<ReviewSummaryModel> fetchReviewSummary(String jlptLevel);

  Future<ChapterListModel> fetchChapters(String jlptLevel);

  Future<LessonDetailModel> fetchLessonDetail(String lessonId);

  Future<LessonProgressModel> startLesson(String lessonId);

  Future<LessonSubmitResultModel> submitLesson(
    String lessonId,
    List<Map<String, dynamic>> answers,
  );
}
