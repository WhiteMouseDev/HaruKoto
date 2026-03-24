import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/feedback_model.dart';
import 'chat_provider.dart';

final conversationFeedbackProvider =
    FutureProvider.autoDispose.family<FeedbackSummary?, String>(
  (ref, conversationId) async {
    final detail = await ref
        .watch(chatRepositoryProvider)
        .fetchConversation(conversationId);
    return detail.feedbackSummary;
  },
);
