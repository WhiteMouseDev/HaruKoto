import 'chat_message_model.dart';
import 'conversation_model.dart';
import 'feedback_model.dart';
import 'scenario_model.dart';

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
              json['feedbackSummary'] as Map<String, dynamic>,
            )
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
              json['feedbackSummary'] as Map<String, dynamic>,
            )
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
  final String? feedbackError;
  final int xpEarned;
  final List<ChatGameEvent> events;

  const LiveFeedbackResponse({
    required this.conversationId,
    this.feedbackSummary,
    this.feedbackError,
    required this.xpEarned,
    required this.events,
  });

  factory LiveFeedbackResponse.fromJson(Map<String, dynamic> json) {
    return LiveFeedbackResponse(
      conversationId: json['conversationId'] as String? ?? '',
      feedbackSummary: json['feedbackSummary'] != null
          ? FeedbackSummary.fromJson(
              json['feedbackSummary'] as Map<String, dynamic>,
            )
          : null,
      feedbackError: json['feedbackError'] as String?,
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
  final String model;

  const LiveTokenResponse({
    required this.token,
    required this.wsUri,
    required this.model,
  });

  factory LiveTokenResponse.fromJson(Map<String, dynamic> json) {
    return LiveTokenResponse(
      token: json['token'] as String? ?? '',
      wsUri: json['wsUri'] as String? ?? '',
      model: json['model'] as String? ?? '',
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
