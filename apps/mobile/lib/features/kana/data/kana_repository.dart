import 'package:dio/dio.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/network_base.dart';
import 'models/kana_character_model.dart';
import '../domain/kana_card_progress.dart';
import 'models/kana_progress_model.dart';
import 'models/kana_stage_model.dart';

class KanaRepository {
  final Dio _dio;

  KanaRepository(this._dio, [this._currentOwner]) {
    _guard = InterceptorsWrapper(onRequest: (options, handler) {
      final expected = options.extra[_ownerKey];
      if (expected != null && expected != _currentOwner?.call()) {
        handler.reject(DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error:
              const ApiException(message: '학습 계정이 변경되었어요. 학습 화면에서 다시 시작해 주세요.'),
        ));
        return;
      }
      handler.next(options);
    });
    _dio.interceptors.add(_guard);
  }

  final String? Function()? _currentOwner;
  late final Interceptor _guard;
  static const _ownerKey = '_kanaExpectedOwner';

  void dispose() => _dio.interceptors.remove(_guard);

  Options _writeOptions() {
    final owner = _currentOwner?.call();
    if (_currentOwner != null && owner == null) {
      throw const ApiException(message: '로그인이 필요합니다.', statusCode: 401);
    }
    return Options(extra: {
      if (owner != null) _ownerKey: owner,
      // UI retries preserve the session and payload. Do not replay an old write
      // after token refresh against a different currently signed-in account.
      RequestMetadata.skipAuthRefresh: true,
      RequestMetadata.skipNetworkRetry: true,
    });
  }

  Future<List<KanaCharacterModel>> fetchCharacters(
    String type, {
    String? category,
  }) async {
    final queryParams = <String, dynamic>{'kana_type': type};
    if (category != null) queryParams['category'] = category;

    final response = await _dio.get<List<dynamic>>(
      '/kana/characters',
      queryParameters: queryParams,
    );
    return response.data!
        .map((e) => KanaCharacterModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<KanaStageModel>> fetchStages(String type) async {
    final response = await _dio.get<List<dynamic>>(
      '/kana/stages',
      queryParameters: {'kana_type': type},
    );
    return response.data!
        .map((e) => KanaStageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<KanaProgressModel> fetchProgress() async {
    final response = await _dio.get<Map<String, dynamic>>('/kana/progress');
    return KanaProgressModel.fromJson(response.data!);
  }

  Future<KanaCardReceipt> submitCardProgress(KanaCardActivity request,
      {CancelToken? cancelToken}) async {
    if (_currentOwner != null && _currentOwner() != request.owner) {
      throw const ApiException(
          message: '학습 계정이 변경되었어요. 학습 화면에서 다시 시작해 주세요.', statusCode: 403);
    }
    final response = await _dio.post<Map<String, dynamic>>(
      '/kana/progress/activities',
      options: _writeOptions(),
      data: request.toJson(),
      cancelToken: cancelToken,
    );
    if (_currentOwner != null && _currentOwner() != request.owner) {
      throw const ApiException(
          message: '학습 계정이 변경되었어요. 학습 화면에서 다시 시작해 주세요.', statusCode: 403);
    }
    final data = response.data;
    if (data == null) throw const FormatException('Missing kana card receipt');
    final receipt = KanaCardReceipt.fromJson(data);
    if (receipt.activityId != request.activityId) {
      throw const FormatException('Kana activity identity mismatch');
    }
    return receipt;
  }

  Future<void> updateProgress({
    required String kanaId,
    required bool learned,
  }) async {
    await _dio.post<dynamic>(
      '/kana/progress',
      options: _writeOptions(),
      data: {'kanaId': kanaId, 'learned': learned},
    );
  }

  Future<void> completeStage({
    required String stageId,
    int? quizScore,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/kana/stage-complete',
      options: _writeOptions(),
      data: {'stageId': stageId, if (quizScore != null) 'quizScore': quizScore},
    );
    if (response.data?['success'] != true) {
      throw const FormatException('Missing kana stage acknowledgement');
    }
  }

  Future<StartQuizResponse> startQuiz({
    required String kanaType,
    int? stageNumber,
    required String quizMode,
    required int count,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/kana/quiz/start',
      options: _writeOptions(),
      data: {
        'kanaType': kanaType,
        if (stageNumber != null) 'stageNumber': stageNumber,
        'quizMode': quizMode,
        'count': count,
      },
    );
    return StartQuizResponse.fromJson(response.data!);
  }

  Future<({bool isCorrect, String correctOptionId})> answerQuestion({
    required String sessionId,
    required String questionId,
    required String selectedOptionId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/kana/quiz/answer',
      options: _writeOptions(),
      data: {
        'sessionId': sessionId,
        'questionId': questionId,
        'selectedOptionId': selectedOptionId,
      },
    );
    final data = response.data;
    if (data == null ||
        data['isCorrect'] is! bool ||
        data['correctOptionId'] is! String ||
        (data['correctOptionId'] as String).trim().isEmpty) {
      throw const FormatException('Missing kana answer acknowledgement');
    }
    return (
      isCorrect: data['isCorrect'] as bool,
      correctOptionId: data['correctOptionId'] as String,
    );
  }

  Future<CompleteQuizResponse> completeQuiz({
    required String sessionId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/kana/quiz/complete',
      options: _writeOptions(),
      data: {'sessionId': sessionId},
    );
    final data = response.data;
    if (data == null ||
        ['accuracy', 'xpEarned', 'currentXp', 'xpForNext', 'level']
            .any((key) => data[key] is! int) ||
        (data['accuracy'] as int) < 0 ||
        (data['accuracy'] as int) > 100 ||
        (data['xpEarned'] as int) < 0 ||
        (data['currentXp'] as int) < 0 ||
        (data['xpForNext'] as int) <= 0 ||
        (data['level'] as int) < 1) {
      throw const FormatException('Missing kana completion acknowledgement');
    }
    return CompleteQuizResponse.fromJson(data);
  }
}
