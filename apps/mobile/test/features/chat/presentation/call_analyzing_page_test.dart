import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/chat_repository.dart';
import 'package:harukoto_mobile/features/chat/data/models/feedback_model.dart';
import 'package:harukoto_mobile/features/chat/presentation/call_analyzing_page.dart';
import 'package:harukoto_mobile/features/chat/presentation/conversation_feedback_page.dart';
import 'package:harukoto_mobile/features/chat/providers/chat_provider.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_provider.dart';

void main() {
  group('CallAnalyzingPage', () {
    testWidgets('navigates to the feedback report after analysis completes',
        (tester) async {
      final repository = _FakeChatRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWith((ref) => repository),
          ],
          child: MaterialApp(
            home: CallAnalyzingPage(
              request: const VoiceCallAnalysisRequest(
                transcript: [
                  {'role': 'user', 'text': 'こんにちは'},
                ],
                durationSeconds: 24,
                characterName: 'Unknown',
                scenarioId: 'scenario-1',
              ),
              feedbackLauncher: (context, analysis) {
                return Navigator.of(context).pushReplacement<void, void>(
                  PageRouteBuilder<void>(
                    pageBuilder: (_, __, ___) => ConversationFeedbackPage(
                      conversationId: analysis.conversationId!,
                      initialFeedback: analysis.feedbackSummary,
                    ),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 350));

      expect(repository.calls, 1);
      expect(find.text('회화 리포트'), findsOneWidget);
      expect(find.text('잘한 표현'), findsOneWidget);
    });
  });
}

class _FakeChatRepository extends ChatRepository {
  _FakeChatRepository() : super(Dio());

  int calls = 0;

  @override
  Future<LiveFeedbackResponse> sendLiveFeedback({
    required List<Map<String, String>> transcript,
    required int durationSeconds,
    String? scenarioId,
    String? characterId,
  }) async {
    calls++;
    return LiveFeedbackResponse(
      conversationId: 'conversation-1',
      feedbackSummary: _buildFeedbackSummary(),
      xpEarned: 8,
      events: const [],
    );
  }
}

FeedbackSummary _buildFeedbackSummary() {
  return const FeedbackSummary(
    overallScore: 91,
    fluency: 88,
    accuracy: 90,
    vocabularyDiversity: 87,
    naturalness: 92,
    strengths: ['자연스럽게 인사를 시작했어요'],
    improvements: ['문장을 조금 더 길게 말해보세요'],
    recommendedExpressions: [],
    corrections: [],
    translatedTranscript: [],
  );
}
