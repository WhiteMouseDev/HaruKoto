import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/features/chat/data/models/scenario_model.dart';
import 'package:harukoto_mobile/features/chat/presentation/chat_hub_page.dart';
import 'package:harukoto_mobile/features/chat/presentation/voice_call_page.dart';
import 'package:harukoto_mobile/features/chat/presentation/voice_call_summary_page.dart';
import 'package:harukoto_mobile/features/chat/presentation/widgets/expression_practice_card.dart';
import 'package:harukoto_mobile/features/chat/presentation/widgets/scenario_preparation_sheet.dart';
import 'package:harukoto_mobile/features/chat/providers/chat_provider.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_provider.dart';
import 'package:harukoto_mobile/features/study/data/models/wordbook_entry_model.dart';
import 'package:harukoto_mobile/features/study/domain/study_repository.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _hotel = ScenarioModel(
  id: 'hotel',
  title: '호텔 체크인',
  titleJa: 'ホテルのチェックイン',
  description: '예약을 확인하고 체크인해 보세요.',
  category: 'TRAVEL',
  difficulty: 'N5',
  estimatedMinutes: 3,
  keyExpressions: ['予約しています。'],
  situation: '호텔 프런트에서 체크인하기',
  yourRole: '투숙객',
  aiRole: '프런트 직원',
);

void main() {
  for (final scale in [1.0, 1.6]) {
    testWidgets('both modes remain usable at 320px with text scale $scale',
        (tester) async {
      _smallViewport(tester);
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          chatHistoryProvider.overrideWith((ref) async => []),
        ],
        child: _app(const ChatHubPage(), scale),
      ));
      await tester.pumpAndSettle();
      expect(find.text('회화 연습'), findsOneWidget);
      expect(find.text('친구와 통화'), findsOneWidget);
      await tester.tap(find.text('친구와 통화'));
      await tester.pumpAndSettle();
      expect(find.text('친구에게 전화하기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('hotel preparation remains scrollable at text scale $scale',
        (tester) async {
      _smallViewport(tester);
      await tester.pumpWidget(_app(
        const Scaffold(body: ScenarioPreparationSheet(scenario: _hotel)),
        scale,
      ));
      await tester.pumpAndSettle();
      expect(find.text('예약을 확인하고 체크인해 보세요.'), findsNothing);
      expect(find.text('나의 역할: 투숙객\n상대 역할: 프런트 직원'), findsOneWidget);
      await tester.ensureVisible(find.text('글로 연습'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('microphone recovery stays actionable at text scale $scale',
        (tester) async {
      _smallViewport(tester);
      final controller = _InterruptedCall();
      await tester.pumpWidget(ProviderScope(
        overrides: [voiceCallSessionProvider.overrideWith(() => controller)],
        child: _app(const VoiceCallPage(characterName: '하루'), scale),
      ));
      await tester.pump();
      expect(find.text('마이크 일시중지'), findsOneWidget);
      await tester.tap(find.text('마이크 다시 연결'));
      await tester.pump();
      expect(controller.recoveryRequests, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('saved friend call can finish without feedback at scale $scale',
        (tester) async {
      _smallViewport(tester);
      var feedbackRequests = 0;
      await tester.pumpWidget(_app(
        VoiceCallSummaryPage(
          request: const VoiceCallAnalysisRequest(
            transcript: [
              {'role': 'user', 'text': '今日は楽しかった。'},
            ],
            durationSeconds: 65,
            characterName: '하루',
            recordSaved: true,
            analysisEnabled: false,
          ),
          onRequestFeedback: () => feedbackRequests++,
        ),
        scale,
      ));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('마치기'), 150);
      expect(feedbackRequests, 0);
      expect(find.text('원할 때 피드백 보기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('expression recall and save lead to the existing wordbook',
      (tester) async {
    _smallViewport(tester);
    final repository = _ExpressionRepository();
    await tester.pumpWidget(ProviderScope(
      overrides: [studyRepositoryProvider.overrideWithValue(repository)],
      child: _app(
        const Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              child: ExpressionPracticeCard(
                expression: '予約しています。',
                meaning: '예약했어요.',
              ),
            ),
          ),
        ),
        1.6,
      ),
    ));
    await tester.tap(find.text('혼자 다시 말해보기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('녹음하지 않아요'), findsOneWidget);
    await tester.ensureVisible(find.text('표현 펼쳐서 확인'));
    await tester.tap(find.text('표현 펼쳐서 확인'));
    await tester.pumpAndSettle();
    expect(find.text('다시 가리고 연습'), findsOneWidget);
    await tester.ensureVisible(find.text('마치기'));
    await tester.tap(find.text('마치기'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('단어장에 표현 저장'));
    await tester.tap(find.text('단어장에 표현 저장'));
    await tester.pumpAndSettle();
    expect(repository.preserveExisting, isTrue);
    await tester.ensureVisible(find.text('단어장에서 보기'));
    await tester.tap(find.text('단어장에서 보기'));
    await tester.pumpAndSettle();
    expect(find.text('내 단어장'), findsOneWidget);
    expect(find.text('予約しています。'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _smallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(Widget home, double scale) => MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: home,
    );

class _InterruptedCall extends VoiceCallSessionController {
  int recoveryRequests = 0;
  @override
  VoiceCallSessionState build() => const VoiceCallSessionState(
        status: VoiceCallStatus.connected,
        hasConnected: true,
        microphoneInterrupted: true,
      );
  @override
  Future<void> initialize(VoiceCallSessionRequest request) async {}
  @override
  Future<bool> resumeMicrophone() async {
    recoveryRequests++;
    return true;
  }
}

class _ExpressionRepository implements StudyRepository {
  bool preserveExisting = false;
  @override
  Future<void> addWord({
    required String word,
    required String reading,
    required String meaningKo,
    String source = 'MANUAL',
    bool preserveExisting = false,
    String? note,
  }) async {
    this.preserveExisting = preserveExisting;
  }

  @override
  Future<({List<WordbookEntryModel> entries, int total, int totalPages})>
      fetchWordbook({
    int page = 1,
    String sort = 'recent',
    String search = '',
    String filter = 'ALL',
    int limit = 20,
  }) async =>
          (
            entries: preserveExisting
                ? const [
                    WordbookEntryModel(
                      id: 'saved-expression',
                      word: '予約しています。',
                      reading: '',
                      meaningKo: '예약했어요.',
                      source: 'CONVERSATION',
                      createdAt: '2026-11-03T00:00:00Z',
                    ),
                  ]
                : <WordbookEntryModel>[],
            total: preserveExisting ? 1 : 0,
            totalPages: 1,
          );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
