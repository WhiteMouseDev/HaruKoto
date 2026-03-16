import 'package:dio/dio.dart';
import 'models/kana_character_model.dart';
import 'models/kana_progress_model.dart';
import 'models/kana_stage_model.dart';

class KanaRepository {
  final Dio _dio;

  KanaRepository(this._dio);

  Future<List<KanaCharacterModel>> fetchCharacters(
    String type, {
    String? category,
  }) async {
    final queryParams = <String, dynamic>{'type': type};
    if (category != null) queryParams['category'] = category;

    final response = await _dio.get<Map<String, dynamic>>(
      '/kana/characters',
      queryParameters: queryParams,
    );
    final characters = response.data!['characters'] as List<dynamic>;
    return characters
        .map((e) => KanaCharacterModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<KanaStageModel>> fetchStages(String type) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/kana/stages',
      queryParameters: {'type': type},
    );
    final stages = response.data!['stages'] as List<dynamic>;
    return stages
        .map((e) => KanaStageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<KanaProgressModel> fetchProgress() async {
    final response = await _dio.get<Map<String, dynamic>>('/kana/progress');
    return KanaProgressModel.fromJson(response.data!);
  }

  Future<void> updateProgress({
    required String kanaId,
    required bool learned,
  }) async {
    await _dio.post<dynamic>(
      '/kana/progress',
      data: {'kanaId': kanaId, 'learned': learned},
    );
  }

  Future<void> completeStage({
    required String stageId,
    int? quizScore,
  }) async {
    await _dio.post<dynamic>(
      '/kana/stage-complete',
      data: {'stageId': stageId, if (quizScore != null) 'quizScore': quizScore},
    );
  }

  Future<StartQuizResponse> startQuiz({
    required String kanaType,
    int? stageNumber,
    required String quizMode,
    required int count,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/kana/quiz/start',
      data: {
        'kanaType': kanaType,
        if (stageNumber != null) 'stageNumber': stageNumber,
        'quizMode': quizMode,
        'count': count,
      },
    );
    return StartQuizResponse.fromJson(response.data!);
  }

  Future<void> answerQuestion({
    required String sessionId,
    required String questionId,
    required String selectedOptionId,
  }) async {
    await _dio.post<dynamic>(
      '/kana/quiz/answer',
      data: {
        'sessionId': sessionId,
        'questionId': questionId,
        'selectedOptionId': selectedOptionId,
      },
    );
  }

  Future<CompleteQuizResponse> completeQuiz({
    required String sessionId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/kana/quiz/complete',
      data: {'sessionId': sessionId},
    );
    return CompleteQuizResponse.fromJson(response.data!);
  }
}
