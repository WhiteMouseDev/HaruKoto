import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../home/providers/study_activity_refresh_provider.dart';

import '../data/chat_repository.dart' as chat_data;
import 'chat_provider.dart';
import 'conversation_feedback_provider.dart';

final conversationEndServiceProvider = Provider<ConversationEndService>((ref) {
  return ConversationEndService(ref);
});

class ConversationEndService {
  const ConversationEndService(this._ref);

  final Ref _ref;

  Future<chat_data.EndConversationResponse> endConversation(
    String conversationId,
  ) async {
    final response =
        await _ref.read(chatRepositoryProvider).endConversation(conversationId);
    if (_ref.mounted) {
      _ref.invalidate(chatHistoryProvider);
      _ref.invalidate(conversationFeedbackProvider(conversationId));
      if (response.success) _ref.read(studyActivityRefreshProvider).refresh();
    }
    return response;
  }
}
