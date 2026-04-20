import 'package:dio/dio.dart';
import 'models/chat_message_model.dart';
import 'models/chat_response_models.dart';
import 'models/scenario_model.dart';
import 'models/character_model.dart';

export 'models/chat_response_models.dart';

abstract class ChatRepository {
  const ChatRepository();

  // ---------- Scenarios ----------

  Future<List<ScenarioModel>> fetchScenarios({String? category}) async {
    throw UnimplementedError();
  }

  // ---------- Chat History ----------

  Future<HistoryPage> fetchHistory({int limit = 5, String? cursor}) async {
    throw UnimplementedError();
  }

  Future<void> deleteConversation(String conversationId) async {
    throw UnimplementedError();
  }

  // ---------- Conversation ----------

  Future<StartConversationResponse> startConversation(String scenarioId) async {
    throw UnimplementedError();
  }

  Future<ConversationDetail> fetchConversation(String conversationId) async {
    throw UnimplementedError();
  }

  Future<MessageResponse> sendMessage({
    required String conversationId,
    required String message,
  }) async {
    throw UnimplementedError();
  }

  Future<EndConversationResponse> endConversation(String conversationId) async {
    throw UnimplementedError();
  }

  // ---------- Characters ----------

  Future<List<CharacterListItem>> fetchCharacters() async {
    throw UnimplementedError();
  }

  Future<CharacterDetail> fetchCharacterDetail(String characterId) async {
    throw UnimplementedError();
  }

  Future<Map<String, int>> fetchCharacterStats() async {
    throw UnimplementedError();
  }

  Future<Set<String>> fetchCharacterFavorites() async {
    throw UnimplementedError();
  }

  Future<bool> toggleFavorite(String characterId) async {
    throw UnimplementedError();
  }

  // ---------- Live token ----------

  Future<LiveTokenResponse> fetchLiveToken({String? characterId}) async {
    throw UnimplementedError();
  }

  // ---------- Live feedback (voice call) ----------

  Future<LiveFeedbackResponse> sendLiveFeedback({
    required List<Map<String, String>> transcript,
    required int durationSeconds,
    String? scenarioId,
    String? characterId,
  }) async {
    throw UnimplementedError();
  }
}

class DioChatRepository extends ChatRepository {
  final Dio _dio;

  const DioChatRepository(this._dio);

  // ---------- Scenarios ----------

  @override
  Future<List<ScenarioModel>> fetchScenarios({String? category}) async {
    final query = category != null ? '?category=$category' : '';
    final response = await _dio.get<List<dynamic>>('/chat/scenarios$query');
    return (response.data ?? [])
        .map((e) => ScenarioModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------- Chat History ----------

  @override
  Future<HistoryPage> fetchHistory({int limit = 5, String? cursor}) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null) params['cursor'] = cursor;
    final response = await _dio.get<Map<String, dynamic>>('/chat/history',
        queryParameters: params);
    return HistoryPage.fromJson(response.data!);
  }

  @override
  Future<void> deleteConversation(String conversationId) async {
    await _dio.delete<void>('/chat/$conversationId');
  }

  // ---------- Conversation ----------

  @override
  Future<StartConversationResponse> startConversation(String scenarioId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/chat/start',
      data: {'scenarioId': scenarioId},
    );
    return StartConversationResponse.fromJson(response.data!);
  }

  @override
  Future<ConversationDetail> fetchConversation(String conversationId) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/chat/$conversationId');
    return ConversationDetail.fromJson(response.data!);
  }

  @override
  Future<MessageResponse> sendMessage({
    required String conversationId,
    required String message,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/chat/message',
      data: {'conversationId': conversationId, 'message': message},
    );
    return MessageResponse.fromJson(response.data!);
  }

  @override
  Future<EndConversationResponse> endConversation(String conversationId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/chat/end',
      data: {'conversationId': conversationId},
    );
    return EndConversationResponse.fromJson(response.data!);
  }

  // ---------- Characters ----------

  @override
  Future<List<CharacterListItem>> fetchCharacters() async {
    final response = await _dio.get<Map<String, dynamic>>('/chat/characters');
    final list = response.data!['characters'] as List<dynamic>? ?? [];
    return list
        .map((e) => CharacterListItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<CharacterDetail> fetchCharacterDetail(String characterId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/chat/characters',
      queryParameters: {'id': characterId},
    );
    return CharacterDetail.fromJson(
      response.data!['character'] as Map<String, dynamic>? ?? {},
    );
  }

  @override
  Future<Map<String, int>> fetchCharacterStats() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/chat/characters/stats');
    final raw = response.data!['characterStats'] as Map<String, dynamic>? ?? {};
    return raw.map((k, v) => MapEntry(k, v as int? ?? 0));
  }

  @override
  Future<Set<String>> fetchCharacterFavorites() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/chat/characters/favorites');
    final list = response.data!['favoriteIds'] as List<dynamic>? ?? [];
    return list.map((e) => e as String).toSet();
  }

  @override
  Future<bool> toggleFavorite(String characterId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/chat/characters/favorites',
      data: {'characterId': characterId},
    );
    return response.data!['favorited'] as bool? ?? false;
  }

  // ---------- Live token ----------

  @override
  Future<LiveTokenResponse> fetchLiveToken({String? characterId}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/chat/live-token',
      data: {
        if (characterId != null) 'characterId': characterId,
      },
    );
    return LiveTokenResponse.fromJson(response.data!);
  }

  // ---------- Live feedback (voice call) ----------

  @override
  Future<LiveFeedbackResponse> sendLiveFeedback({
    required List<Map<String, String>> transcript,
    required int durationSeconds,
    String? scenarioId,
    String? characterId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/chat/live-feedback',
      data: {
        'transcript': transcript,
        'durationSeconds': durationSeconds,
        if (scenarioId != null) 'scenarioId': scenarioId,
        if (characterId != null) 'characterId': characterId,
      },
    );
    return LiveFeedbackResponse.fromJson(response.data!);
  }
}
