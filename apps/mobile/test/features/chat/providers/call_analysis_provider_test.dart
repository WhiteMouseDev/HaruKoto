import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/chat_repository.dart';
import 'package:harukoto_mobile/features/chat/data/models/feedback_model.dart';
import 'package:harukoto_mobile/features/chat/providers/call_analysis_provider.dart';
import 'package:harukoto_mobile/features/chat/providers/chat_provider.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_provider.dart';

void main() {
  group('CallAnalysisController', () {
    test('analyze completes with feedback result', () async {
      final repository = _FakeChatRepository(
        response: LiveFeedbackResponse(
          conversationId: 'conversation-1',
          feedbackSummary: _feedbackSummary(),
          xpEarned: 12,
          events: const [],
        ),
      );
      final container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWith((ref) => repository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(callAnalysisProvider.notifier);
      await notifier.analyze(
        const VoiceCallAnalysisRequest(
          transcript: [
            {'role': 'user', 'text': 'こんにちは'},
          ],
          durationSeconds: 22,
          characterId: 'char-1',
          scenarioId: 'scenario-1',
        ),
      );

      final state = container.read(callAnalysisProvider);
      expect(repository.calls, 1);
      expect(repository.lastDurationSeconds, 22);
      expect(repository.lastCharacterId, 'char-1');
      expect(repository.lastScenarioId, 'scenario-1');
      expect(state.status, CallAnalysisStatus.completed);
      expect(state.currentStep, 3);
      expect(state.progress, 1.0);
      expect(state.conversationId, 'conversation-1');
      expect(state.feedbackSummary, isNotNull);
    });

    test('retry reuses the previous request after failure', () async {
      final repository = _FakeChatRepository(
        errorsBeforeSuccess: 1,
        response: const LiveFeedbackResponse(
          conversationId: 'conversation-2',
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

      final notifier = container.read(callAnalysisProvider.notifier);
      await notifier.analyze(
        const VoiceCallAnalysisRequest(
          transcript: [
            {'role': 'user', 'text': 'もしもし'},
          ],
          durationSeconds: 18,
        ),
      );

      expect(container.read(callAnalysisProvider).status,
          CallAnalysisStatus.error);

      await notifier.retry();

      final state = container.read(callAnalysisProvider);
      expect(repository.calls, 2);
      expect(state.status, CallAnalysisStatus.completed);
      expect(state.conversationId, 'conversation-2');
    });
  });
}

class _FakeChatRepository extends ChatRepository {
  _FakeChatRepository({
    required this.response,
    this.errorsBeforeSuccess = 0,
  });

  final LiveFeedbackResponse response;
  final int errorsBeforeSuccess;
  int calls = 0;
  int? lastDurationSeconds;
  String? lastCharacterId;
  String? lastScenarioId;

  @override
  Future<LiveFeedbackResponse> sendLiveFeedback({
    required List<Map<String, String>> transcript,
    required int durationSeconds,
    String? scenarioId,
    String? characterId,
  }) async {
    calls++;
    lastDurationSeconds = durationSeconds;
    lastCharacterId = characterId;
    lastScenarioId = scenarioId;

    if (calls <= errorsBeforeSuccess) {
      throw Exception('analysis failed');
    }
    return response;
  }
}

FeedbackSummary _feedbackSummary() {
  return const FeedbackSummary(
    overallScore: 88,
    fluency: 84,
    accuracy: 86,
    vocabularyDiversity: 90,
    naturalness: 89,
    strengths: ['자연스러운 인사'],
    improvements: ['속도를 조금만 늦추기'],
    recommendedExpressions: [],
    corrections: [],
    translatedTranscript: [],
  );
}
