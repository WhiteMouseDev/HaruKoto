import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/auth/current_account_provider.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/features/chat/data/chat_repository.dart';
import 'package:harukoto_mobile/features/chat/data/models/conversation_journey_episode.dart';
import 'package:harukoto_mobile/features/chat/providers/call_analysis_service.dart';
import 'package:harukoto_mobile/features/chat/providers/chat_provider.dart';
import 'package:harukoto_mobile/features/chat/providers/conversation_journey_progress_provider.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_analysis_request_factory.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _spoken = [
  {'role': 'assistant', 'text': 'どちらまでですか。'},
  {'role': 'user', 'text': '新宿までお願いします。'},
];

const _saved = LiveFeedbackResponse(
  conversationId: 'saved-conversation',
  xpEarned: 0,
  events: [],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('marks practice only after confirmed save, even if feedback fails',
      () async {
    final repository = _SaveRepository();
    final container = await _container(repository, () => 'account-a');
    final first = tokyoFirstDayEpisodes.first.scenarioId;
    final service = container.read(callAnalysisServiceProvider);
    final progress = container.read(conversationJourneyProgressStoreProvider);
    final pending = Completer<LiveFeedbackResponse>();
    repository.save = () => pending.future;

    final saving = service.analyze(_request(first));
    expect(await progress.load('account-a'), isEmpty);
    pending.complete(const LiveFeedbackResponse(
      conversationId: 'saved-without-feedback',
      feedbackError: 'generation_failed',
      xpEarned: 0,
      events: [],
    ));
    expect((await saving).feedbackError, 'generation_failed');
    expect(await progress.load('account-a'), {first});
    expect(await progress.load('account-b'), isEmpty);
  });

  test('skips failed saves, disconnected calls, and transcripts without speech',
      () async {
    final repository = _SaveRepository();
    final container = await _container(repository, () => 'account-a');
    final first = tokyoFirstDayEpisodes.first.scenarioId;
    final service = container.read(callAnalysisServiceProvider);
    final progress = container.read(conversationJourneyProgressStoreProvider);

    repository.save = () async => throw StateError('backend rejected save');
    await expectLater(service.analyze(_request(first)), throwsStateError);
    repository.save = () async => _saved;
    await service.analyze(_request(first, wasConnected: false));
    await service.analyze(_request(first, transcript: const [
      {'role': 'assistant', 'text': 'こんばんは。'},
      {'role': 'user', 'text': '  '},
    ]));
    await service.analyze(_request('an-unrelated-scenario'));
    repository.save = () async => const LiveFeedbackResponse(
          conversationId: 'saved-without-speech',
          feedbackError: 'no_transcript',
          xpEarned: 0,
          events: [],
        );
    await service.analyze(_request(first));
    expect(await progress.load('account-a'), isEmpty);
  });

  test('serializes distinct and repeated saves without losing local progress',
      () async {
    final repository = _SaveRepository();
    final container = await _container(repository, () => 'account-a');
    final first = tokyoFirstDayEpisodes[0].scenarioId;
    final second = tokyoFirstDayEpisodes[1].scenarioId;
    final service = container.read(callAnalysisServiceProvider);
    await Future.wait([
      service.analyze(_request(first)),
      service.analyze(_request(second)),
      service.analyze(_request(first)),
    ]);
    final preferences = await SharedPreferences.getInstance();
    final reopened = ConversationJourneyProgressStore(preferences);
    expect(await reopened.load('account-a'), {first, second});
    expect(await reopened.load('account-b'), isEmpty);
  });

  test('a late save after an account switch cannot mark either account',
      () async {
    final repository = _SaveRepository();
    var account = 'account-a';
    final container = await _container(repository, () => account);
    final first = tokyoFirstDayEpisodes.first.scenarioId;
    final progress = container.read(conversationJourneyProgressStoreProvider);
    final pending = Completer<LiveFeedbackResponse>();
    repository.save = () => pending.future;
    final saving =
        container.read(callAnalysisServiceProvider).analyze(_request(first));
    account = 'account-b';
    pending.complete(_saved);
    expect((await saving).conversationId, 'saved-conversation');
    expect(await progress.load('account-a'), isEmpty);
    expect(await progress.load('account-b'), isEmpty);
  });
}

Future<ProviderContainer> _container(
  _SaveRepository repository,
  String? Function() readAccount,
) async {
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    chatRepositoryProvider.overrideWithValue(repository),
    currentAccountReaderProvider.overrideWithValue(readAccount),
    sharedPreferencesProvider.overrideWithValue(preferences),
  ]);
  addTearDown(container.dispose);
  return container;
}

VoiceCallAnalysisRequest _request(
  String scenarioId, {
  List<Map<String, String>> transcript = _spoken,
  bool wasConnected = true,
}) =>
    VoiceCallAnalysisRequest(
      transcript: transcript,
      durationSeconds: 30,
      wasConnected: wasConnected,
      scenarioId: scenarioId,
      conversationId: 'prepared-conversation',
    );

class _SaveRepository extends ChatRepository {
  Future<LiveFeedbackResponse> Function() save = () async => _saved;

  @override
  Future<LiveFeedbackResponse> sendLiveFeedback({
    required List<Map<String, String>> transcript,
    required int durationSeconds,
    bool analysisEnabled = true,
    String? conversationId,
    String? scenarioId,
    String? characterId,
  }) =>
      save();
}
