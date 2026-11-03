import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/feedback_model.dart';
import '../data/models/chat_response_models.dart';
import 'chat_provider.dart';

final conversationDetailProvider =
    FutureProvider.autoDispose.family<ConversationDetail, String>(
  (ref, conversationId) =>
      ref.watch(chatRepositoryProvider).fetchConversation(conversationId),
);

final conversationFeedbackProvider =
    FutureProvider.autoDispose.family<FeedbackSummary?, String>(
  (ref, conversationId) async {
    final detail = await ref
        .watch(chatRepositoryProvider)
        .fetchConversation(conversationId);
    return detail.feedbackSummary;
  },
);
