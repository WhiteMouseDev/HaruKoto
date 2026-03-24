import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/chat_message_model.dart';
import '../data/models/scenario_model.dart';
import 'chat_provider.dart';

class ConversationBootstrapData {
  const ConversationBootstrapData({
    this.scenario,
    required this.messages,
    this.currentHint,
  });

  final ScenarioModel? scenario;
  final List<ChatMessageModel> messages;
  final String? currentHint;
}

final conversationBootstrapProvider =
    FutureProvider.autoDispose.family<ConversationBootstrapData, String>(
  (ref, conversationId) async {
    final detail = await ref
        .watch(chatRepositoryProvider)
        .fetchConversation(conversationId);
    return ConversationBootstrapData(
      scenario: detail.scenario,
      messages: List<ChatMessageModel>.unmodifiable(detail.messages),
    );
  },
);
