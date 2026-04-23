import 'package:flutter/material.dart';

import '../data/models/chat_message_model.dart';
import '../data/models/feedback_model.dart';
import 'conversation_feedback_page.dart';

MaterialPageRoute<void> conversationFeedbackRoute({
  required String conversationId,
  FeedbackSummary? initialFeedback,
  String? initialFeedbackError,
  List<VocabularyItem>? vocabulary,
}) {
  return MaterialPageRoute(
    builder: (_) => ConversationFeedbackPage(
      conversationId: conversationId,
      initialFeedback: initialFeedback,
      initialFeedbackError: initialFeedbackError,
      vocabulary: vocabulary,
    ),
  );
}

void openConversationFeedbackPage(
  BuildContext context, {
  required String conversationId,
  FeedbackSummary? initialFeedback,
  String? initialFeedbackError,
  List<VocabularyItem>? vocabulary,
  bool replace = false,
}) {
  final route = conversationFeedbackRoute(
    conversationId: conversationId,
    initialFeedback: initialFeedback,
    initialFeedbackError: initialFeedbackError,
    vocabulary: vocabulary,
  );
  final navigator = Navigator.of(context);
  if (replace) {
    navigator.pushReplacement(route);
    return;
  }
  navigator.push(route);
}
