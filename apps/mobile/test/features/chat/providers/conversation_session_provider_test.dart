import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/chat_repository.dart';
import 'package:harukoto_mobile/features/chat/data/models/chat_message_model.dart';
import 'package:harukoto_mobile/features/chat/data/models/feedback_model.dart';
import 'package:harukoto_mobile/features/chat/data/models/scenario_model.dart';
import 'package:harukoto_mobile/features/chat/presentation/conversation_launch.dart';
import 'package:harukoto_mobile/features/chat/providers/chat_provider.dart';
import 'package:harukoto_mobile/features/chat/providers/conversation_session_provider.dart';

void main() {
  group('ConversationSessionController', () {
    test('initializes from launch payload without remote bootstrap', () async {
      final repository = _FakeChatRepository();
      final container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWith((ref) => repository),
        ],
      );
      addTearDown(container.dispose);

      await container.read(conversationSessionProvider.notifier).initialize(
            const ConversationLaunchRequest(
              conversationId: 'conversation-1',
              initialScenario: ScenarioModel(
                id: 'scenario-1',
                title: '카페 주문',
                titleJa: 'カフェで注文',
                description: '카페에서 주문하기',
                category: 'DAILY',
                difficulty: 'BEGINNER',
                estimatedMinutes: 5,
                keyExpressions: ['コーヒー'],
                situation: '카페 상황',
                yourRole: '손님',
                aiRole: '점원',
              ),
              firstMessage: FirstMessage(
                messageJa: 'いらっしゃいませ',
                messageKo: '어서 오세요',
                hint: '커피를 주문해 보세요',
              ),
            ),
          );

      final state = container.read(conversationSessionProvider);
      expect(repository.fetchConversationCalls, 0);
      expect(state.isReady, isTrue);
      expect(state.scenario?.title, '카페 주문');
      expect(state.messages, hasLength(1));
      expect(state.currentHint, '커피를 주문해 보세요');
    });

    test('sendMessage appends AI response and feedback', () async {
      final repository = _FakeChatRepository();
      final container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWith((ref) => repository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(conversationSessionProvider.notifier);
      await notifier.initialize(
        const ConversationLaunchRequest(
          conversationId: 'conversation-2',
          firstMessage: FirstMessage(
            messageJa: 'こんにちは',
            messageKo: '안녕하세요',
          ),
        ),
      );

      await notifier.sendMessage('コーヒーをください');

      final state = container.read(conversationSessionProvider);
      expect(repository.sendMessageCalls, 1);
      expect(state.messages, hasLength(3));
      expect(state.messages[1].feedback, isNotEmpty);
      expect(state.messages.last.role, 'ai');
      expect(state.currentHint, '가격도 물어보세요');
      expect(state.allVocabulary, hasLength(1));
      expect(state.isTyping, isFalse);
    });

    test('endConversation returns feedback summary and clears ending state',
        () async {
      final repository = _FakeChatRepository();
      final container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWith((ref) => repository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(conversationSessionProvider.notifier);
      await notifier.initialize(
        const ConversationLaunchRequest(
          conversationId: 'conversation-3',
          firstMessage: FirstMessage(
            messageJa: 'こんにちは',
            messageKo: '안녕하세요',
          ),
        ),
      );
      await notifier.sendMessage('注文したいです');

      final result = await notifier.endConversation();

      final state = container.read(conversationSessionProvider);
      expect(repository.endConversationCalls, 1);
      expect(result?.feedbackSummary?.overallScore, 91);
      expect(state.isEnding, isFalse);
      expect(state.errorMessage, isNull);
    });
  });
}

class _FakeChatRepository extends ChatRepository {
  _FakeChatRepository() : super(Dio());

  int fetchConversationCalls = 0;
  int sendMessageCalls = 0;
  int endConversationCalls = 0;

  @override
  Future<ConversationDetail> fetchConversation(String conversationId) async {
    fetchConversationCalls++;
    return const ConversationDetail(
      scenario: ScenarioModel(
        id: 'scenario-remote',
        title: '식당 주문',
        titleJa: 'レストランで注文',
        description: '식당에서 주문하기',
        category: 'DAILY',
        difficulty: 'BEGINNER',
        estimatedMinutes: 5,
        keyExpressions: ['注文'],
        situation: '식당 상황',
        yourRole: '손님',
        aiRole: '점원',
      ),
      messages: [
        ChatMessageModel(
          id: 'ai-remote',
          role: 'ai',
          messageJa: '何にしますか',
          messageKo: '무엇으로 하시겠어요?',
        ),
      ],
    );
  }

  @override
  Future<MessageResponse> sendMessage({
    required String conversationId,
    required String message,
  }) async {
    sendMessageCalls++;
    return const MessageResponse(
      messageJa: 'コーヒーですね',
      messageKo: '커피시군요',
      feedback: [
        MessageFeedback(
          type: 'grammar',
          original: 'コーヒーをください',
          correction: 'コーヒーをお願いします',
          explanationKo: '더 자연스러운 표현입니다',
        ),
      ],
      hint: '가격도 물어보세요',
      newVocabulary: [
        VocabularyItem(
          word: '会計',
          reading: 'かいけい',
          meaningKo: '계산',
        ),
      ],
    );
  }

  @override
  Future<EndConversationResponse> endConversation(String conversationId) async {
    endConversationCalls++;
    return const EndConversationResponse(
      success: true,
      feedbackSummary: FeedbackSummary(
        overallScore: 91,
        fluency: 90,
        accuracy: 92,
        vocabularyDiversity: 88,
        naturalness: 93,
        strengths: ['자연스러운 표현'],
        improvements: ['속도를 조금 더 늦추기'],
        recommendedExpressions: [],
        corrections: [],
        translatedTranscript: [],
      ),
      xpEarned: 10,
      events: [],
    );
  }
}
