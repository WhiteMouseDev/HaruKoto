import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/chat_repository.dart';
import 'package:harukoto_mobile/features/chat/data/models/chat_message_model.dart';
import 'package:harukoto_mobile/features/chat/data/models/conversation_model.dart';
import 'package:harukoto_mobile/features/chat/data/models/feedback_model.dart';
import 'package:harukoto_mobile/features/chat/data/models/scenario_model.dart';
import 'package:harukoto_mobile/features/chat/providers/chat_provider.dart';
import 'package:harukoto_mobile/features/chat/providers/conversation_bootstrap_provider.dart';
import 'package:harukoto_mobile/features/chat/providers/conversation_end_provider.dart';

void main() {
  group('conversation flow providers', () {
    test('conversationBootstrapProvider loads scenario and messages', () async {
      final repository = _FakeChatRepository(
        detail: ConversationDetail(
          scenario: _scenario(),
          messages: const [
            ChatMessageModel(
              id: 'm1',
              role: 'ai',
              messageJa: 'こんにちは',
              messageKo: '안녕하세요',
            ),
          ],
        ),
        historyPage: const HistoryPage(history: []),
        endResponse: const EndConversationResponse(
          success: true,
          xpEarned: 0,
          events: [],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWith((ref) => repository),
        ],
      );
      addTearDown(container.dispose);

      final data = await container.read(
        conversationBootstrapProvider('conversation-1').future,
      );

      expect(repository.fetchConversationCalls, 1);
      expect(repository.lastFetchedConversationId, 'conversation-1');
      expect(data.scenario?.title, '카페 주문');
      expect(data.messages, hasLength(1));
      expect(data.messages.first.messageJa, 'こんにちは');
    });

    test('conversationEndService ends conversation and invalidates history',
        () async {
      final repository = _FakeChatRepository(
        detail: const ConversationDetail(messages: []),
        historyPage: const HistoryPage(
          history: [
            ConversationModel(
              id: 'conversation-1',
              type: 'TEXT',
              createdAt: '2026-03-24T00:00:00Z',
              messageCount: 2,
            ),
          ],
        ),
        endResponse: EndConversationResponse(
          success: true,
          feedbackSummary: _feedbackSummary(),
          xpEarned: 20,
          events: const [
            ChatGameEvent(
              type: 'xp',
              title: 'XP',
              body: '20xp',
              emoji: '✨',
            ),
          ],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWith((ref) => repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(chatHistoryProvider.future);
      expect(repository.fetchHistoryCalls, 1);

      final response = await container
          .read(conversationEndServiceProvider)
          .endConversation('conversation-1');

      expect(repository.endConversationCalls, 1);
      expect(repository.lastEndedConversationId, 'conversation-1');
      expect(response.feedbackSummary?.overallScore, 87);

      await container.read(chatHistoryProvider.future);
      expect(repository.fetchHistoryCalls, 2);
    });
  });
}

class _FakeChatRepository extends ChatRepository {
  _FakeChatRepository({
    required this.detail,
    required this.historyPage,
    required this.endResponse,
  }) : super(Dio());

  final ConversationDetail detail;
  final HistoryPage historyPage;
  final EndConversationResponse endResponse;

  int fetchConversationCalls = 0;
  int fetchHistoryCalls = 0;
  int endConversationCalls = 0;
  String? lastFetchedConversationId;
  String? lastEndedConversationId;

  @override
  Future<ConversationDetail> fetchConversation(String conversationId) async {
    fetchConversationCalls++;
    lastFetchedConversationId = conversationId;
    return detail;
  }

  @override
  Future<HistoryPage> fetchHistory({int limit = 5, String? cursor}) async {
    fetchHistoryCalls++;
    return historyPage;
  }

  @override
  Future<EndConversationResponse> endConversation(String conversationId) async {
    endConversationCalls++;
    lastEndedConversationId = conversationId;
    return endResponse;
  }
}

ScenarioModel _scenario() {
  return const ScenarioModel(
    id: 'scenario-1',
    title: '카페 주문',
    titleJa: 'カフェで注文',
    description: '카페에서 커피 주문하기',
    category: 'DAILY',
    difficulty: 'BEGINNER',
    estimatedMinutes: 5,
    keyExpressions: ['コーヒーをください'],
    situation: '카페에서 주문하는 상황',
    yourRole: '손님',
    aiRole: '점원',
  );
}

FeedbackSummary _feedbackSummary() {
  return const FeedbackSummary(
    overallScore: 87,
    fluency: 85,
    accuracy: 86,
    vocabularyDiversity: 88,
    naturalness: 89,
    strengths: ['자연스러운 인사'],
    improvements: ['질문에 조금 더 길게 답하기'],
    recommendedExpressions: [],
    corrections: [],
    translatedTranscript: [],
  );
}
