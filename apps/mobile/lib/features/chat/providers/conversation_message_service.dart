import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_repository.dart';
import '../data/models/chat_message_model.dart';
import 'chat_provider.dart';

final conversationMessageServiceProvider =
    Provider<ConversationMessageService>((ref) {
  return ConversationMessageService(ref.watch(chatRepositoryProvider));
});

class ConversationMessageReply {
  const ConversationMessageReply({
    required this.userFeedback,
    required this.aiMessage,
    this.hint,
    required this.newVocabulary,
  });

  final List<MessageFeedback> userFeedback;
  final ChatMessageModel aiMessage;
  final String? hint;
  final List<VocabularyItem> newVocabulary;
}

class ConversationMessageService {
  const ConversationMessageService(this._repository);

  final ChatRepository _repository;

  Future<ConversationMessageReply> send({
    required String conversationId,
    required String message,
    required String aiMessageId,
  }) async {
    final response = await _repository.sendMessage(
      conversationId: conversationId,
      message: message,
    );

    return ConversationMessageReply(
      userFeedback: response.feedback,
      aiMessage: ChatMessageModel(
        id: aiMessageId,
        role: 'ai',
        messageJa: response.messageJa,
        messageKo: response.messageKo,
      ),
      hint: response.hint,
      newVocabulary: response.newVocabulary,
    );
  }
}
