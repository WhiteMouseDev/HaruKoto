class ChatMessageModel {
  final String id;
  final String role; // 'ai' | 'user'
  final String messageJa;
  final String? messageKo;
  final List<MessageFeedback>? feedback;

  const ChatMessageModel({
    required this.id,
    required this.role,
    required this.messageJa,
    this.messageKo,
    this.feedback,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as String? ?? '',
      role: json['role'] as String? ?? 'ai',
      messageJa: json['messageJa'] as String? ?? '',
      messageKo: json['messageKo'] as String?,
      feedback: (json['feedback'] as List<dynamic>?)
          ?.map((e) => MessageFeedback.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  ChatMessageModel copyWith({
    String? id,
    String? role,
    String? messageJa,
    String? messageKo,
    List<MessageFeedback>? feedback,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      role: role ?? this.role,
      messageJa: messageJa ?? this.messageJa,
      messageKo: messageKo ?? this.messageKo,
      feedback: feedback ?? this.feedback,
    );
  }
}

class MessageFeedback {
  final String type;
  final String original;
  final String correction;
  final String explanationKo;

  const MessageFeedback({
    required this.type,
    required this.original,
    required this.correction,
    required this.explanationKo,
  });

  factory MessageFeedback.fromJson(Map<String, dynamic> json) {
    return MessageFeedback(
      type: json['type'] as String? ?? '',
      original: json['original'] as String? ?? '',
      correction: json['correction'] as String? ?? '',
      explanationKo: json['explanationKo'] as String? ?? '',
    );
  }
}

class MessageResponse {
  final String messageJa;
  final String messageKo;
  final List<MessageFeedback> feedback;
  final String? hint;
  final List<VocabularyItem> newVocabulary;

  const MessageResponse({
    required this.messageJa,
    required this.messageKo,
    required this.feedback,
    this.hint,
    required this.newVocabulary,
  });

  factory MessageResponse.fromJson(Map<String, dynamic> json) {
    return MessageResponse(
      messageJa: json['messageJa'] as String? ?? '',
      messageKo: json['messageKo'] as String? ?? '',
      feedback: (json['feedback'] as List<dynamic>?)
              ?.map(
                  (e) => MessageFeedback.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      hint: json['hint'] as String?,
      newVocabulary: (json['newVocabulary'] as List<dynamic>?)
              ?.map(
                  (e) => VocabularyItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class VocabularyItem {
  final String word;
  final String reading;
  final String meaningKo;

  const VocabularyItem({
    required this.word,
    required this.reading,
    required this.meaningKo,
  });

  factory VocabularyItem.fromJson(Map<String, dynamic> json) {
    return VocabularyItem(
      word: json['word'] as String? ?? '',
      reading: json['reading'] as String? ?? '',
      meaningKo: json['meaningKo'] as String? ?? '',
    );
  }
}

class StartConversationResponse {
  final String conversationId;
  final FirstMessage firstMessage;

  const StartConversationResponse({
    required this.conversationId,
    required this.firstMessage,
  });

  factory StartConversationResponse.fromJson(Map<String, dynamic> json) {
    return StartConversationResponse(
      conversationId: json['conversationId'] as String,
      firstMessage: FirstMessage.fromJson(
          json['firstMessage'] as Map<String, dynamic>),
    );
  }
}

class FirstMessage {
  final String messageJa;
  final String messageKo;
  final String? hint;

  const FirstMessage({
    required this.messageJa,
    required this.messageKo,
    this.hint,
  });

  factory FirstMessage.fromJson(Map<String, dynamic> json) {
    return FirstMessage(
      messageJa: json['messageJa'] as String? ?? '',
      messageKo: json['messageKo'] as String? ?? '',
      hint: json['hint'] as String?,
    );
  }
}
