import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/constants/colors.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/features/chat/data/chat_repository.dart';
import 'package:harukoto_mobile/features/chat/data/models/conversation_model.dart';
import 'package:harukoto_mobile/features/chat/data/models/conversation_journey_episode.dart';
import 'package:harukoto_mobile/features/chat/data/models/scenario_model.dart';
import 'package:harukoto_mobile/features/chat/presentation/chat_entry_mode.dart';
import 'package:harukoto_mobile/features/chat/presentation/chat_hub_page.dart';
import 'package:harukoto_mobile/features/chat/presentation/voice_call_record_page.dart';
import 'package:harukoto_mobile/features/chat/presentation/widgets/conversation_journey_elements.dart';
import 'package:harukoto_mobile/features/chat/presentation/widgets/conversation_journey_sheet.dart';
import 'package:harukoto_mobile/features/chat/presentation/widgets/scenario_list_view.dart';
import 'package:harukoto_mobile/features/chat/presentation/widgets/text_tab.dart';
import 'package:harukoto_mobile/features/chat/providers/chat_provider.dart';
import 'package:harukoto_mobile/features/chat/providers/conversation_journey_progress_provider.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const hotel = ScenarioModel(
    id: 'hotel-id',
    title: '호텔 체크인',
    titleJa: 'ホテル',
    description: '예약을 확인해 보세요',
    category: 'TRAVEL',
    difficulty: 'N5',
    estimatedMinutes: 3,
    keyExpressions: ['予約しています。'],
    situation: '호텔 프런트에서 체크인하기',
    yourRole: '투숙객',
    aiRole: '프런트 직원');

void main() {
  testWidgets('incomplete catalog keeps existing categories available',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentAccountIdProvider.overrideWithValue('pilot-account'),
        sharedPreferencesProvider.overrideWithValue(preferences),
        chatHistoryProvider.overrideWith((ref) async => []),
        scenariosProvider('TRAVEL').overrideWith(
          (ref) async =>
              tokyoFirstDayEpisodes.take(2).map(_scenarioFor).toList(),
        ),
      ],
      child: const MaterialApp(home: ChatHubPage()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('도쿄에서의 첫날'), findsNothing);
    await tester.tap(find.text('여행'));
    await tester.pumpAndSettle();
    expect(find.text('공항에서 시내행 열차표 사기'), findsOneWidget);
    expect(find.text('카페에서 테이크아웃'), findsNothing);
    await tester.tap(find.text('공항에서 시내행 열차표 사기'));
    await tester.pumpAndSettle();
    expect(find.text('1. 시내행 열차편 묻기'), findsOneWidget);
  });

  testWidgets(
      'pilot recommends the next unpracticed scene and allows any scene',
      (tester) async {
    const owner = 'pilot-account';
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final controller = _SessionController();
    await ConversationJourneyProgressStore(preferences).markPracticed(
      owner,
      tokyoFirstDayEpisodes.first.scenarioId,
      isCurrentAccount: () => true,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentAccountIdProvider.overrideWithValue(owner),
        currentAccountReaderProvider.overrideWithValue(() => owner),
        sharedPreferencesProvider.overrideWithValue(preferences),
        chatHistoryProvider.overrideWith((ref) async => []),
        scenariosProvider('TRAVEL').overrideWith(
          (ref) async => tokyoFirstDayEpisodes.map(_scenarioFor).toList(),
        ),
        voiceCallSessionProvider.overrideWith(() => controller),
      ],
      child: const MaterialApp(home: ChatHubPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('체크인 전 짐 맡기기'), findsOneWidget);
    expect(find.text('1 / 3장면'), findsOneWidget);
    expect(find.text('연습 전'), findsOneWidget);
    expect(find.text('중급'), findsOneWidget);
    expect(find.text('약 5분'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('중급')).dx,
      lessThan(tester.getTopLeft(find.text('연습 전')).dx),
    );
    final hubProgress = find.byType(ConversationJourneyProgressSummary);
    expect(tester.getSize(hubProgress).height, 32);
    expect(_decorationOf(tester, hubProgress).color, AppColors.redesignSurface);
    expect(_decorationOf(tester, hubProgress).border, isNull);
    final progressLeft = tester.getTopLeft(hubProgress).dx;
    expect(tester.getTopLeft(find.text('도쿄에서의 첫날')).dx, progressLeft);
    expect(tester.getTopLeft(find.text('이어서 말하기')).dx, progressLeft + 8);
    expect(
      _episodeRing(tester, find.byType(ConversationJourneyEpisodeNumber)),
      const BorderSide(color: AppColors.redesignOutline, width: 4),
    );

    final prepare = find.text('연습 시작');
    await tester.ensureVisible(prepare);
    await tester.tap(prepare);
    await tester.pumpAndSettle();
    expect(find.text('1. 체크인 시작 시간 묻기'), findsOneWidget);
    expect(find.textContaining(' · 약 5분'), findsOneWidget);
    Navigator.of(tester.element(find.text('1. 체크인 시작 시간 묻기'))).pop();
    await tester.pumpAndSettle();

    final viewJourney = find.text('장면 전체 보기');
    await tester.ensureVisible(viewJourney);
    await tester.tap(viewJourney);
    await tester.pumpAndSettle();
    final sheet = find.byType(ConversationJourneySheet);
    Finder inSheet(String value) =>
        find.descendant(of: sheet, matching: find.text(value));
    expect(inSheet('도쿄에서의 첫날'), findsOneWidget);
    expect(inSheet('추천 순서대로,\n또는 필요한 장면부터 골라요.'), findsOneWidget);
    expect(inSheet('연습 현황'), findsOneWidget);
    expect(inSheet('1 / 3장면'), findsOneWidget);
    expect(inSheet('연습함'), findsOneWidget);
    expect(inSheet('연습 전'), findsNWidgets(2));
    expect(inSheet('다음 추천'), findsOneWidget);
    expect(inSheet('초급'), findsOneWidget);
    expect(inSheet('중급'), findsOneWidget);
    expect(inSheet('고급'), findsOneWidget);
    expect(inSheet('약 5분'), findsOneWidget);
    expect(inSheet('약 3분'), findsNWidgets(2));
    expect(inSheet('공항 매표소에서 신주쿠까지 가는 열차를 물어보고 표 한 장을 사요.'), findsOneWidget);
    final listProgress = find.descendant(
      of: sheet,
      matching: find.byType(ConversationJourneyProgressSummary),
    );
    final firstCard = find.widgetWithText(OutlinedButton, '공항에서 시내행 열차표 사기');
    expect(tester.getSize(listProgress).height, 34);
    expect(_decorationOf(tester, listProgress).color, isNull);
    expect(
      _decorationOf(tester, listProgress).border?.top.color,
      AppColors.redesignOutline,
    );
    expect(
      tester.getTopLeft(firstCard).dy - tester.getBottomLeft(listProgress).dy,
      40,
    );
    final firstRing = find.descendant(
      of: firstCard,
      matching: find.byType(ConversationJourneyEpisodeNumber),
    );
    expect(
      _episodeRing(tester, firstRing),
      const BorderSide(color: AppColors.redesignVocabulary, width: 4),
    );
    await tester.tap(inSheet('카페에서 테이크아웃'));
    await tester.pumpAndSettle();
    expect(find.text('1. 아이스 커피 한 잔 주문하기'), findsOneWidget);
    final speak = find.text('말하기로 연습');
    await tester.ensureVisible(speak);
    await tester.tap(speak);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
        controller.request?.scenarioId, tokyoFirstDayEpisodes.last.scenarioId);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('saved scenes show practiced status at narrow, scaled viewports',
      (tester) async {
    const owner = 'completed-pilot';
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final store = ConversationJourneyProgressStore(preferences);
    for (final episode in tokyoFirstDayEpisodes) {
      await store.markPracticed(
        owner,
        episode.scenarioId,
        isCurrentAccount: () => true,
      );
    }

    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 44);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentAccountIdProvider.overrideWithValue(owner),
        currentAccountReaderProvider.overrideWithValue(() => owner),
        sharedPreferencesProvider.overrideWithValue(preferences),
        chatHistoryProvider.overrideWith((ref) async => []),
        scenariosProvider('TRAVEL').overrideWith(
          (ref) async => tokyoFirstDayEpisodes.map(_scenarioFor).toList(),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const ChatHubPage(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('다시 말하기'), findsOneWidget);
    final sceneCount = find.text('3 / 3장면');
    expect(sceneCount, findsOneWidget);
    expect(tester.getTopRight(sceneCount).dx, greaterThan(280));

    expect(find.text('공항에서 시내행 열차표 사기'), findsOneWidget);
    expect(
      find.text('공항 매표소에서 신주쿠까지 가는 열차를 물어보고 표 한 장을 사요.'),
      findsOneWidget,
    );
    expect(find.text('연습함'), findsOneWidget);
    expect(find.text('약 3분'), findsOneWidget);
    final prepare = find.text('연습 시작');
    await tester.dragUntilVisible(
      prepare.hitTestable(),
      find.byType(TextTab),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(prepare);
    await tester.pumpAndSettle();
    expect(find.text('1. 시내행 열차편 묻기'), findsOneWidget);
    Navigator.of(tester.element(find.text('1. 시내행 열차편 묻기'))).pop();
    await tester.pumpAndSettle();

    final viewJourney = find.text('장면 전체 보기');
    await tester.dragUntilVisible(
      viewJourney.hitTestable(),
      find.byType(TextTab),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(viewJourney);
    await tester.pumpAndSettle();
    final title = find.descendant(
      of: find.byType(ConversationJourneySheet),
      matching: find.text('도쿄에서의 첫날'),
    );
    expect(tester.getTopLeft(title).dy, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'hotel preparation forwards the selected scenario to voice and text paths',
      (tester) async {
    final controller = _SessionController();
    ScenarioModel? selectedText;
    await tester.pumpWidget(ProviderScope(
        overrides: [
          scenariosProvider('TRAVEL').overrideWith((ref) async => [hotel]),
          voiceCallSessionProvider.overrideWith(() => controller),
        ],
        child: MaterialApp(
            home: ScenarioListView(
          category: 'TRAVEL',
          entryMode: ChatEntryMode.text,
          starting: false,
          onBack: () {},
          onStartConversation: (scenario) => selectedText = scenario,
        ))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('호텔 체크인'));
    await tester.pumpAndSettle();
    expect(find.text('나의 역할: 투숙객\n상대 역할: 프런트 직원'), findsOneWidget);
    expect(find.text('予約しています。'), findsOneWidget);
    await tester.tap(find.text('글로 연습'));
    await tester.pumpAndSettle();
    expect(selectedText?.id, hotel.id);
    await tester.tap(find.text('호텔 체크인'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('말하기로 연습'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.request?.scenarioId, hotel.id);
    expect(find.text('프런트 직원'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
      'saved voice record reads content without automatically analyzing',
      (tester) async {
    final repository = _RecordRepository(ended: true);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          chatRepositoryProvider.overrideWith((ref) => repository),
        ],
        child: const MaterialApp(
            home: VoiceCallRecordPage(
                conversation: ConversationModel(
          id: 'saved-id',
          type: 'VOICE',
          createdAt: '2026-11-03T12:00:00Z',
          messageCount: 2,
        )))));
    await tester.pumpAndSettle();
    expect(find.text('予約しています。'), findsOneWidget);
    expect(find.text('お名前は？'), findsOneWidget);
    expect(find.text('internal secret prompt'), findsNothing);
    expect(find.text('저장된 대화 2개 발화'), findsOneWidget);
    expect(repository.calls, 0);
    expect(find.text('이 대화 피드백 요청하기'), findsOneWidget);
    await tester.tap(find.text('이 대화 피드백 요청하기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(repository.calls, 1);
    expect(repository.id, 'saved-id');
    expect(repository.duration, 0);
    expect(repository.analysisEnabled, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
      'unfinished history explicitly closes a prepared id without analysis',
      (tester) async {
    final repository = _RecordRepository(ended: false);
    await tester.pumpWidget(ProviderScope(
        overrides: [
          chatRepositoryProvider.overrideWith((ref) => repository),
        ],
        child: const MaterialApp(
            home: VoiceCallRecordPage(
                conversation: ConversationModel(
          id: 'saved-id',
          type: 'VOICE',
          createdAt: '2026-11-03T12:00:00Z',
          messageCount: 0,
        )))));
    await tester.pumpAndSettle();
    expect(find.text('마무리되지 않은 연결 준비 기록'), findsOneWidget);
    expect(find.text('이 대화 피드백 요청하기'), findsNothing);
    await tester.tap(find.text('연결 준비 기록 정리하기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(repository.analysisEnabled, isFalse);
    expect(repository.duration, 0);
    expect(find.text('통화를 시작하지 못했어요'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}

BorderSide _episodeRing(WidgetTester tester, Finder sign) =>
    _decorationOf(tester, sign).border!.top;

BoxDecoration _decorationOf(WidgetTester tester, Finder widget) {
  final container = tester.widget<Container>(
    find.descendant(of: widget, matching: find.byType(Container)),
  );
  return container.decoration! as BoxDecoration;
}

ScenarioModel _scenarioFor(ConversationJourneyEpisode episode) => ScenarioModel(
      id: episode.scenarioId,
      title: episode.title,
      titleJa: episode.place,
      description: episode.goals.first,
      category: 'TRAVEL',
      difficulty: switch (episode.number) {
        2 => 'INTERMEDIATE',
        3 => 'ADVANCED',
        _ => 'BEGINNER',
      },
      estimatedMinutes: switch (episode.number) {
        2 => 5,
        3 => 0,
        _ => episode.estimatedMinutes,
      },
      keyExpressions: episode.examples,
      situation: episode.place,
      yourRole: '여행자',
      aiRole: '직원',
    );

class _SessionController extends VoiceCallSessionController {
  VoiceCallSessionRequest? request;
  @override
  VoiceCallSessionState build() =>
      const VoiceCallSessionState(status: VoiceCallStatus.connected);
  @override
  Future<void> initialize(VoiceCallSessionRequest request) async {
    this.request = request;
  }
}

class _RecordRepository extends ChatRepository {
  _RecordRepository({required this.ended});
  final bool ended;
  int calls = 0;
  String? id;
  int? duration;
  bool? analysisEnabled;
  @override
  Future<ConversationDetail> fetchConversation(String conversationId) async =>
      ConversationDetail.fromJson({
        'endedAt': ended ? '2026-11-03T12:03:00Z' : null,
        'messages': ended
            ? [
                {'role': 'system', 'content': 'internal secret prompt'},
                {'role': 'user', 'content': '予約しています。'},
                {'role': 'assistant', 'content': 'お名前は？'}
              ]
            : [],
      });
  @override
  Future<LiveFeedbackResponse> sendLiveFeedback(
      {required List<Map<String, String>> transcript,
      required int durationSeconds,
      bool analysisEnabled = true,
      String? conversationId,
      String? scenarioId,
      String? characterId}) async {
    calls++;
    id = conversationId;
    duration = durationSeconds;
    this.analysisEnabled = analysisEnabled;
    return const LiveFeedbackResponse(
        conversationId: 'saved-id',
        xpEarned: 0,
        events: [],
        feedbackError: 'no_transcript');
  }
}
