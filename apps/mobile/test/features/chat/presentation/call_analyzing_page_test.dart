import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/features/chat/data/chat_repository.dart';
import 'package:harukoto_mobile/features/chat/data/models/conversation_journey_episode.dart';
import 'package:harukoto_mobile/features/chat/data/models/feedback_model.dart';
import 'package:harukoto_mobile/features/chat/presentation/call_analyzing_page.dart';
import 'package:harukoto_mobile/features/chat/presentation/conversation_feedback_page.dart';
import 'package:harukoto_mobile/features/chat/providers/chat_provider.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_provider.dart';

void main() {
  group('CallAnalyzingPage', () {
    testWidgets('navigates to the feedback report after analysis completes',
        (tester) async {
      final repository = _FakeChatRepository(
        response: LiveFeedbackResponse(
          conversationId: 'conversation-1',
          feedbackSummary: _buildFeedbackSummary(),
          xpEarned: 8,
          events: const [],
        ),
      );

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
      expect(find.text('🦊'), findsNothing);
      expect(find.text('상세 점수 보기'), findsOneWidget);
    });

    testWidgets(
        'social call saves first and analyzes only after an explicit request',
        (tester) async {
      final repository = _FakeChatRepository(
          response: const LiveFeedbackResponse(
        conversationId: 'stable-id',
        xpEarned: 0,
        events: [],
      ));
      await tester.pumpWidget(ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWith((ref) => repository),
          ],
          child: const MaterialApp(
              home: CallAnalyzingPage(
                  request: VoiceCallAnalysisRequest(
            conversationId: 'stable-id',
            transcript: [
              {'role': 'user', 'text': 'こんにちは'}
            ],
            durationSeconds: 24,
            characterName: '하루',
            analysisEnabled: false,
          )))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('하루와의 통화를 마쳤어요'), findsOneWidget);
      expect(find.text('원할 때 피드백 보기'), findsOneWidget);
      expect(repository.analysisFlags, [false]);
      await tester.pump(const Duration(seconds: 2));
      expect(repository.calls, 1);
      await tester.tap(find.text('원할 때 피드백 보기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(repository.analysisFlags, [false, true]);
      expect(repository.ids, ['stable-id', 'stable-id']);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('keeps a saved failed analysis available for retry',
        (tester) async {
      final repository = _FakeChatRepository(
        response: const LiveFeedbackResponse(
          conversationId: 'conversation-generation-failed',
          feedbackError: 'generation_failed',
          xpEarned: 0,
          events: [],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWith((ref) => repository),
          ],
          child: const MaterialApp(
            home: CallAnalyzingPage(
              request: VoiceCallAnalysisRequest(
                transcript: [
                  {'role': 'user', 'text': 'こんにちは'},
                ],
                durationSeconds: 24,
                characterName: 'Unknown',
                scenarioId: 'scenario-1',
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(seconds: 3));

      expect(repository.calls, 1);
      expect(find.text('기록은 저장됐지만 피드백을 만들지 못했어요'), findsOneWidget);
      expect(find.text('피드백 다시 만들기'), findsOneWidget);
      expect(find.text('돌아가기'), findsOneWidget);
    });

    testWidgets(
        'saved pilot call offers optional goal check and existing feedback',
        (tester) async {
      final episode = tokyoFirstDayEpisodes[1];
      final repository = _FakeChatRepository(
        response: LiveFeedbackResponse(
          conversationId: 'pilot-call',
          feedbackSummary: _buildFeedbackSummary(),
          xpEarned: 8,
          events: const [],
        ),
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          chatRepositoryProvider.overrideWithValue(repository),
          currentAccountReaderProvider.overrideWithValue(() => null),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => CallAnalyzingPage(
                      request: VoiceCallAnalysisRequest(
                        scenarioId: episode.scenarioId,
                        transcript: [
                          {'role': 'user', 'text': episode.examples.first},
                        ],
                        durationSeconds: 24,
                      ),
                    ),
                  ),
                ),
                child: const Text('실전회화'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('실전회화'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.text('내가 말해본 목표'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNWidgets(2));
      await tester.tap(find.text(episode.goals.first));
      await tester.pump();
      expect(
          tester
              .widget<CheckboxListTile>(find.byType(CheckboxListTile).first)
              .value,
          isTrue);
      await tester.ensureVisible(find.text('원할 때 피드백 보기'));
      await tester.tap(find.text('원할 때 피드백 보기'));
      await tester.pumpAndSettle();
      expect(find.text('회화 리포트'), findsOneWidget);
      expect(repository.analysisFlags, [true]);

      await tester.tap(find.descendant(
          of: find.byType(AppBar), matching: find.byType(IconButton)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('연습 마치기'));
      await tester.tap(find.text('연습 마치기'));
      await tester.pumpAndSettle();
      expect(find.text('실전회화'), findsOneWidget);
      expect(repository.calls, 1);
    });

    testWidgets('saved pilot with a feedback error can retry the same record',
        (tester) async {
      final repository = _FakeChatRepository(
        response: const LiveFeedbackResponse(
          conversationId: 'pilot-call',
          feedbackError: 'generation_failed',
          xpEarned: 0,
          events: [],
        ),
      );
      await tester.pumpWidget(ProviderScope(
        overrides: [
          chatRepositoryProvider.overrideWithValue(repository),
          currentAccountReaderProvider.overrideWithValue(() => null),
        ],
        child: MaterialApp(
          home: CallAnalyzingPage(
            request: VoiceCallAnalysisRequest(
              conversationId: 'pilot-call',
              scenarioId: tokyoFirstDayEpisodes[1].scenarioId,
              transcript: const [
                {'role': 'user', 'text': '荷物を預けてもいいですか。'},
              ],
              durationSeconds: 24,
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('내가 말해본 목표'), findsOneWidget);
      await tester.ensureVisible(find.text('원할 때 피드백 보기'));
      await tester.tap(find.text('원할 때 피드백 보기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(repository.ids, ['pilot-call', 'pilot-call']);
      expect(find.text('피드백 다시 만들기'), findsOneWidget);
    });
  });
}

class _FakeChatRepository extends ChatRepository {
  _FakeChatRepository({required this.response});

  final LiveFeedbackResponse response;
  int calls = 0;
  final analysisFlags = <bool>[];
  final ids = <String?>[];

  @override
  Future<LiveFeedbackResponse> sendLiveFeedback({
    required List<Map<String, String>> transcript,
    required int durationSeconds,
    bool analysisEnabled = true,
    String? conversationId,
    String? scenarioId,
    String? characterId,
  }) async {
    calls++;
    analysisFlags.add(analysisEnabled);
    ids.add(conversationId);
    return response;
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
