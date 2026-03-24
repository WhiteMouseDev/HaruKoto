import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/chat_repository.dart';
import 'package:harukoto_mobile/features/chat/data/models/feedback_model.dart';
import 'package:harukoto_mobile/features/chat/providers/chat_provider.dart';
import 'package:harukoto_mobile/features/chat/providers/conversation_feedback_provider.dart';

void main() {
  group('conversationFeedbackProvider', () {
    test('loads feedback summary from conversation detail', () async {
      final repository = _FakeChatRepository(
        detail: ConversationDetail(
          messages: const [],
          feedbackSummary: _feedbackSummary(),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWith((ref) => repository),
        ],
      );
      addTearDown(container.dispose);

      final feedback = await container.read(
        conversationFeedbackProvider('conversation-1').future,
      );

      expect(repository.fetchCalls, 1);
      expect(repository.lastConversationId, 'conversation-1');
      expect(feedback, isNotNull);
      expect(feedback!.overallScore, 92);
    });

    test('propagates fetch failures', () async {
      final repository = _FakeChatRepository(
        detail: const ConversationDetail(messages: []),
        throwOnFetch: true,
      );
      final container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWith((ref) => repository),
        ],
      );
      addTearDown(container.dispose);
      final provider = conversationFeedbackProvider('conversation-2');
      final subscription = container.listen(provider, (_, __) {});
      addTearDown(subscription.close);

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final state = subscription.read();
      expect(repository.fetchCalls, 1);
      expect(state.hasError, isTrue);
    });
  });
}

class _FakeChatRepository extends ChatRepository {
  _FakeChatRepository({
    required this.detail,
    this.throwOnFetch = false,
  }) : super(Dio());

  final ConversationDetail detail;
  final bool throwOnFetch;
  int fetchCalls = 0;
  String? lastConversationId;

  @override
  Future<ConversationDetail> fetchConversation(String conversationId) async {
    fetchCalls++;
    lastConversationId = conversationId;
    if (throwOnFetch) {
      throw Exception('fetch failed');
    }
    return detail;
  }
}

FeedbackSummary _feedbackSummary() {
  return const FeedbackSummary(
    overallScore: 92,
    fluency: 91,
    accuracy: 90,
    vocabularyDiversity: 93,
    naturalness: 94,
    strengths: ['자연스러운 응답'],
    improvements: ['조금 더 구체적으로 말하기'],
    recommendedExpressions: [],
    corrections: [],
    translatedTranscript: [],
  );
}
