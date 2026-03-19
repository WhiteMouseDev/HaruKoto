import 'package:dio/dio.dart';
import 'models/quiz_question_model.dart';
import 'models/quiz_session_model.dart';
import 'models/quiz_result_model.dart';
import 'models/smart_preview_model.dart';
import 'models/stage_model.dart';
import 'models/word_entry_model.dart';
import 'models/wordbook_entry_model.dart';
import 'models/recommendation_model.dart';

class StudyRepository {
  final Dio _dio;

  StudyRepository(this._dio);

  // ── Stages ──

  Future<List<StageModel>> fetchStages(
      String category, String jlptLevel) async {
    final response = await _dio.get<List<dynamic>>(
      '/study/stages',
      queryParameters: {'category': category, 'jlptLevel': jlptLevel},
    );
    return (response.data ?? [])
        .map((e) => StageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Quiz ──

  Future<IncompleteSessionModel?> fetchIncompleteQuiz() async {
    final response = await _dio.get<Map<String, dynamic>>('/quiz/incomplete');
    final session = response.data!['session'];
    if (session == null) return null;
    return IncompleteSessionModel.fromJson(session as Map<String, dynamic>);
  }

  Future<StudyStatsModel> fetchQuizStats(String level, String type) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/quiz/stats',
      queryParameters: {'level': level, 'type': type},
    );
    return StudyStatsModel.fromJson(response.data!);
  }

  Future<RecommendationModel> fetchRecommendations() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/quiz/recommendations');
    return RecommendationModel.fromJson(response.data!);
  }

  // ── Smart Quiz ──

  Future<SmartPreviewModel> fetchSmartPreview({
    String category = 'VOCABULARY',
    String jlptLevel = 'N5',
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/quiz/smart-preview',
      queryParameters: {'category': category, 'jlptLevel': jlptLevel},
    );
    return SmartPreviewModel.fromJson(response.data!);
  }

  Future<({String sessionId, List<QuizQuestionModel> questions})>
      startSmartQuiz({
    String category = 'VOCABULARY',
    String jlptLevel = 'N5',
    int count = 20,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/quiz/smart-start',
      data: {
        'category': category,
        'jlptLevel': jlptLevel,
        'count': count,
      },
    );
    final data = response.data!;
    return (
      sessionId: data['sessionId'] as String,
      questions: (data['questions'] as List<dynamic>? ?? [])
          .map((e) => QuizQuestionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<({String sessionId, List<QuizQuestionModel> questions})> startQuiz({
    required String quizType,
    required String jlptLevel,
    required int count,
    String? mode,
    String? stageId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/quiz/start',
      data: {
        'quizType': quizType,
        'jlptLevel': jlptLevel,
        'count': count,
        if (mode != null) 'mode': mode,
        if (stageId != null) 'stageId': stageId,
      },
    );
    final data = response.data!;

    // API may return matchingPairs for matching mode instead of questions
    List<QuizQuestionModel> questions;
    if (data['matchingPairs'] != null) {
      questions = (data['matchingPairs'] as List<dynamic>? ?? []).map((e) {
        final pair = e as Map<String, dynamic>;
        return QuizQuestionModel.fromJson({
          'questionId': pair['id'] as String,
          'questionText': pair['word'] as String,
          'questionSubText': pair['reading'] as String?,
          'word': pair['word'] as String,
          'meaning': pair['meaning'] as String,
          'options': <Map<String, dynamic>>[],
          'correctOptionId': '',
        });
      }).toList();
    } else {
      questions = (data['questions'] as List<dynamic>? ?? [])
          .map((e) => QuizQuestionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return (
      sessionId: data['sessionId'] as String,
      questions: questions,
    );
  }

  Future<
      ({
        String sessionId,
        List<QuizQuestionModel> questions,
        List<String> answeredQuestionIds,
        int correctCount,
        String? quizType,
      })> resumeQuiz(String sessionId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/quiz/resume',
      data: {'sessionId': sessionId},
    );
    final data = response.data!;
    return (
      sessionId: data['sessionId'] as String,
      questions: (data['questions'] as List<dynamic>? ?? [])
          .map((e) => QuizQuestionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      answeredQuestionIds: (data['answeredQuestionIds'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      correctCount: data['correctCount'] as int,
      quizType: data['quizType'] as String?,
    );
  }

  Future<void> answerQuestion({
    required String sessionId,
    required String questionId,
    required String selectedOptionId,
    required bool isCorrect,
    required int timeSpentSeconds,
    required String questionType,
  }) async {
    await _dio.post('/quiz/answer', data: {
      'sessionId': sessionId,
      'questionId': questionId,
      'selectedOptionId': selectedOptionId,
      'isCorrect': isCorrect,
      'timeSpentSeconds': timeSpentSeconds,
      'questionType': questionType,
    });
  }

  Future<QuizResultModel> completeQuiz(
    String sessionId, {
    String? stageId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/quiz/complete',
      data: {
        'sessionId': sessionId,
        if (stageId != null) 'stageId': stageId,
      },
    );
    return QuizResultModel.fromJson(response.data!);
  }

  Future<List<WrongAnswerModel>> fetchWrongAnswersBySession(
      String sessionId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/quiz/wrong-answers',
      queryParameters: {'sessionId': sessionId},
    );
    final list = response.data!['wrongAnswers'] as List<dynamic>? ?? [];
    return list
        .map((e) => WrongAnswerModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Wrong Answers Page ──

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
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/study/wrong-answers',
      queryParameters: {'page': page, 'sort': sort, 'limit': limit},
    );
    final data = response.data!;
    return (
      entries: (data['entries'] as List<dynamic>? ?? [])
          .map((e) => WrongEntryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: data['total'] as int? ?? 0,
      totalPages: data['totalPages'] as int? ?? 1,
      summary:
          WrongAnswersSummary.fromJson(data['summary'] as Map<String, dynamic>),
    );
  }

  // ── Learned Words ──

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
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
      'sort': sort,
    };
    if (search.isNotEmpty) params['search'] = search;
    if (filter != 'ALL') params['filter'] = filter;

    final response = await _dio.get<Map<String, dynamic>>(
      '/study/learned-words',
      queryParameters: params,
    );
    final data = response.data!;
    return (
      entries: (data['entries'] as List<dynamic>? ?? [])
          .map((e) => LearnedWordModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: data['total'] as int? ?? 0,
      totalPages: data['totalPages'] as int? ?? 1,
      summary:
          LearnedWordsSummary.fromJson(data['summary'] as Map<String, dynamic>),
    );
  }

  // ── Wordbook ──

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
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'limit': limit,
      'sort': sort,
    };
    if (search.isNotEmpty) params['search'] = search;
    if (filter != 'ALL') params['source'] = filter;

    final response = await _dio.get<Map<String, dynamic>>(
      '/wordbook',
      queryParameters: params,
    );
    final data = response.data!;
    return (
      entries: (data['entries'] as List<dynamic>? ?? [])
          .map((e) => WordbookEntryModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: data['total'] as int? ?? 0,
      totalPages: data['totalPages'] as int? ?? 1,
    );
  }

  Future<void> addWord({
    required String word,
    required String reading,
    required String meaningKo,
    String source = 'MANUAL',
    String? note,
  }) async {
    await _dio.post('/wordbook', data: {
      'word': word,
      'reading': reading,
      'meaningKo': meaningKo,
      'source': source,
      if (note != null) 'note': note,
    });
  }

  Future<void> deleteWord(String id) async {
    await _dio.delete('/wordbook/$id');
  }

  // ── TTS ──

  Future<String> fetchTtsUrl(String vocabId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/vocab/tts',
      data: {'id': vocabId},
    );
    return response.data!['audioUrl'] as String;
  }
}
