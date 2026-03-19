import 'package:dio/dio.dart';
import 'models/conversation_model.dart';
import 'models/chat_message_model.dart';
import 'models/scenario_model.dart';
import 'models/character_model.dart';
import 'models/feedback_model.dart';

class ChatRepository {
  final Dio _dio;

  ChatRepository(this._dio);

  // ---------- Scenarios ----------

  Future<List<ScenarioModel>> fetchScenarios({String? category}) async {
    final query = category != null ? '?category=$category' : '';
    final response = await _dio.get<List<dynamic>>('/chat/scenarios$query');
    return (response.data ?? [])
        .map((e) => ScenarioModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ---------- Chat History ----------

  Future<HistoryPage> fetchHistory({int limit = 5, String? cursor}) async {
    final params = <String, dynamic>{'limit': limit};
    if (cursor != null) params['cursor'] = cursor;
    final response = await _dio.get<Map<String, dynamic>>('/chat/history',
        queryParameters: params);
    return HistoryPage.fromJson(response.data!);
  }

  Future<void> deleteConversation(String conversationId) async {
    await _dio.delete<void>('/chat/$conversationId');
  }

  // ---------- Conversation ----------

  Future<StartConversationResponse> startConversation(String scenarioId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/chat/start',
      data: {'scenarioId': scenarioId},
    );
    return StartConversationResponse.fromJson(response.data!);
  }

  Future<ConversationDetail> fetchConversation(String conversationId) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/chat/$conversationId');
    return ConversationDetail.fromJson(response.data!);
  }

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

  Future<EndConversationResponse> endConversation(String conversationId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/chat/end',
      data: {'conversationId': conversationId},
    );
    return EndConversationResponse.fromJson(response.data!);
  }

  // ---------- Characters ----------

  Future<List<CharacterListItem>> fetchCharacters() async {
    final response = await _dio.get<Map<String, dynamic>>('/chat/characters');
    final list = response.data!['characters'] as List<dynamic>? ?? [];
    return list
        .map((e) => CharacterListItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CharacterDetail> fetchCharacterDetail(String characterId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/chat/characters',
      queryParameters: {'id': characterId},
    );
    return CharacterDetail.fromJson(
      response.data!['character'] as Map<String, dynamic>? ?? {},
    );
  }

  Future<Map<String, int>> fetchCharacterStats() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/chat/characters/stats');
    final raw = response.data!['characterStats'] as Map<String, dynamic>? ?? {};
    return raw.map((k, v) => MapEntry(k, v as int? ?? 0));
  }

  Future<Set<String>> fetchCharacterFavorites() async {
    final response =
        await _dio.get<Map<String, dynamic>>('/chat/characters/favorites');
    final list = response.data!['favoriteIds'] as List<dynamic>? ?? [];
    return list.map((e) => e as String).toSet();
  }

  Future<bool> toggleFavorite(String characterId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/chat/characters/favorites',
      data: {'characterId': characterId},
    );
    return response.data!['favorited'] as bool? ?? false;
  }

  // ---------- Live token ----------

  Future<LiveTokenResponse> fetchLiveToken({String? characterId}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/chat/live-token',
      data: {
        if (characterId != null) 'character_id': characterId,
      },
    );
    return LiveTokenResponse.fromJson(response.data!);
  }

  // ---------- Live feedback (voice call) ----------

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

// ---------- Response types ----------

class HistoryPage {
  final List<ConversationModel> history;
  final String? nextCursor;

  const HistoryPage({required this.history, this.nextCursor});

  factory HistoryPage.fromJson(Map<String, dynamic> json) {
    return HistoryPage(
      history: (json['history'] as List<dynamic>? ?? [])
          .map((e) => ConversationModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['nextCursor'] as String?,
    );
  }
}

class ConversationDetail {
  final List<ChatMessageModel> messages;
  final ScenarioModel? scenario;
  final String? endedAt;
  final FeedbackSummary? feedbackSummary;

  const ConversationDetail({
    required this.messages,
    this.scenario,
    this.endedAt,
    this.feedbackSummary,
  });

  factory ConversationDetail.fromJson(Map<String, dynamic> json) {
    return ConversationDetail(
      messages: (json['messages'] as List<dynamic>? ?? [])
          .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      scenario: json['scenario'] != null
          ? ScenarioModel.fromJson(json['scenario'] as Map<String, dynamic>)
          : null,
      endedAt: json['endedAt'] as String?,
      feedbackSummary: json['feedbackSummary'] != null
          ? FeedbackSummary.fromJson(
              json['feedbackSummary'] as Map<String, dynamic>)
          : null,
    );
  }
}

class EndConversationResponse {
  final bool success;
  final FeedbackSummary? feedbackSummary;
  final int xpEarned;
  final List<ChatGameEvent> events;

  const EndConversationResponse({
    required this.success,
    this.feedbackSummary,
    required this.xpEarned,
    required this.events,
  });

  factory EndConversationResponse.fromJson(Map<String, dynamic> json) {
    return EndConversationResponse(
      success: json['success'] as bool? ?? false,
      feedbackSummary: json['feedbackSummary'] != null
          ? FeedbackSummary.fromJson(
              json['feedbackSummary'] as Map<String, dynamic>)
          : null,
      xpEarned: json['xpEarned'] as int? ?? 0,
      events: (json['events'] as List<dynamic>?)
              ?.map((e) => ChatGameEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class LiveFeedbackResponse {
  final String conversationId;
  final FeedbackSummary? feedbackSummary;
  final int xpEarned;
  final List<ChatGameEvent> events;

  const LiveFeedbackResponse({
    required this.conversationId,
    this.feedbackSummary,
    required this.xpEarned,
    required this.events,
  });

  factory LiveFeedbackResponse.fromJson(Map<String, dynamic> json) {
    return LiveFeedbackResponse(
      conversationId: json['conversationId'] as String? ?? '',
      feedbackSummary: json['feedbackSummary'] != null
          ? FeedbackSummary.fromJson(
              json['feedbackSummary'] as Map<String, dynamic>)
          : null,
      xpEarned: json['xpEarned'] as int? ?? 0,
      events: (json['events'] as List<dynamic>?)
              ?.map((e) => ChatGameEvent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class LiveTokenResponse {
  final String token;
  final String wsUri;

  const LiveTokenResponse({required this.token, required this.wsUri});

  factory LiveTokenResponse.fromJson(Map<String, dynamic> json) {
    return LiveTokenResponse(
      token: json['token'] as String? ?? '',
      wsUri: json['wsUri'] as String? ?? '',
    );
  }
}

class ChatGameEvent {
  final String type;
  final String title;
  final String body;
  final String emoji;

  const ChatGameEvent({
    required this.type,
    required this.title,
    required this.body,
    required this.emoji,
  });

  factory ChatGameEvent.fromJson(Map<String, dynamic> json) {
    return ChatGameEvent(
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '',
    );
  }
}
