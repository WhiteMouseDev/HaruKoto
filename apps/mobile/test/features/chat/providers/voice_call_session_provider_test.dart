import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/core/settings/call_settings.dart';
import 'package:harukoto_mobile/core/providers/user_preferences_provider.dart';
import 'package:harukoto_mobile/core/settings/user_preferences.dart';
import 'package:harukoto_mobile/features/chat/data/chat_repository.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_service.dart';
import 'package:harukoto_mobile/features/chat/data/voice_call_bootstrap_service.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_provider.dart';
import 'package:harukoto_mobile/features/my/data/models/profile_detail_model.dart';
import 'package:harukoto_mobile/features/my/providers/my_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('VoiceCallSessionController', () {
    test('initializes and reacts to live service callbacks', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final bootstrap = _FakeVoiceCallBootstrapService();
      final liveService = _FakeGeminiLiveService();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => prefs),
          profileDetailProvider.overrideWith(
            (ref) => Future.value(
              _profileDetail(
                callSettings: const CallSettings(subtitleEnabled: false),
              ),
            ),
          ),
          voiceCallBootstrapServiceProvider.overrideWith((ref) => bootstrap),
          voiceCallLiveServiceFactoryProvider.overrideWith(
            (ref) => (_, __) => liveService,
          ),
          voiceCallRingtonePlayerFactoryProvider.overrideWith(
            (ref) => _FakeVoiceCallRingtonePlayer.new,
          ),
        ],
      );
      addTearDown(() async {
        await container.read(voiceCallSessionProvider.notifier).endCall();
        container.dispose();
        await Future<void>.delayed(Duration.zero);
      });

      await container.read(userPreferencesProvider.notifier).replace(
            const UserPreferences(
              callSettings: CallSettings(
                subtitleEnabled: false,
              ),
            ),
          );
      await container.read(profileDetailProvider.future);

      await container.read(voiceCallSessionProvider.notifier).initialize(
            const VoiceCallSessionRequest(
              characterId: 'char-1',
              characterName: '하루',
            ),
          );

      expect(bootstrap.prepareCalls, 1);
      expect(liveService.startCalls, 1);

      var state = container.read(voiceCallSessionProvider);
      expect(state.status, VoiceCallStatus.connected);
      expect(state.showSubtitle, isFalse);
      expect(bootstrap.lastInput?.userNickname, 'Tester');

      liveService.emitAiText('こんにちは');
      state = container.read(voiceCallSessionProvider);
      expect(state.currentAiText, 'こんにちは');

      liveService.emitTranscriptEntry(
        const TranscriptEntry(role: 'assistant', text: 'こんにちは'),
      );
      state = container.read(voiceCallSessionProvider);
      expect(state.currentAiText, isEmpty);
    });

    test('toggle controls update local state and live service mute state',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final liveService = _FakeGeminiLiveService();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => prefs),
          profileDetailProvider.overrideWith(
            (ref) => Future.value(_profileDetail()),
          ),
          voiceCallBootstrapServiceProvider.overrideWith(
            (ref) => _FakeVoiceCallBootstrapService(),
          ),
          voiceCallLiveServiceFactoryProvider.overrideWith(
            (ref) => (_, __) => liveService,
          ),
          voiceCallRingtonePlayerFactoryProvider.overrideWith(
            (ref) => _FakeVoiceCallRingtonePlayer.new,
          ),
        ],
      );
      addTearDown(() async {
        await container.read(voiceCallSessionProvider.notifier).endCall();
        container.dispose();
        await Future<void>.delayed(Duration.zero);
      });

      final notifier = container.read(voiceCallSessionProvider.notifier);
      await container.read(profileDetailProvider.future);
      await notifier.initialize(
        const VoiceCallSessionRequest(characterId: 'char-1'),
      );

      notifier.toggleMute();
      notifier.toggleSubtitle();

      final state = container.read(voiceCallSessionProvider);
      expect(state.isMuted, isTrue);
      expect(state.showSubtitle, isFalse);
      expect(liveService.isMuted, isTrue);
    });

    test('initialize reports an error when bootstrap misses live credentials',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var factoryCalls = 0;
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => prefs),
          profileDetailProvider.overrideWith(
            (ref) => Future.value(_profileDetail()),
          ),
          voiceCallBootstrapServiceProvider.overrideWith(
            (ref) => _FakeVoiceCallBootstrapService(token: '', model: ''),
          ),
          voiceCallLiveServiceFactoryProvider.overrideWith(
            (ref) => (_, __) {
              factoryCalls++;
              return _FakeGeminiLiveService();
            },
          ),
          voiceCallRingtonePlayerFactoryProvider.overrideWith(
            (ref) => _FakeVoiceCallRingtonePlayer.new,
          ),
        ],
      );
      addTearDown(() async {
        await container.read(voiceCallSessionProvider.notifier).endCall();
        container.dispose();
        await Future<void>.delayed(Duration.zero);
      });

      final notifier = container.read(voiceCallSessionProvider.notifier);
      await container.read(profileDetailProvider.future);
      await notifier.initialize(
        const VoiceCallSessionRequest(characterId: 'char-1'),
      );

      final state = container.read(voiceCallSessionProvider);
      expect(state.status, VoiceCallStatus.error);
      expect(state.errorMessage, '연결에 실패했습니다');
      expect(factoryCalls, 0);
    });

    test(
        'endCall returns analysis request when transcript and duration qualify',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final liveService = _FakeGeminiLiveService()
        ..providedTranscript = const [
          TranscriptEntry(role: 'user', text: 'もしもし'),
          TranscriptEntry(role: 'assistant', text: 'やっほー'),
        ];
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => prefs),
          profileDetailProvider.overrideWith(
            (ref) => Future.value(_profileDetail()),
          ),
          voiceCallBootstrapServiceProvider.overrideWith(
            (ref) => _FakeVoiceCallBootstrapService(),
          ),
          voiceCallLiveServiceFactoryProvider.overrideWith(
            (ref) => (_, __) => liveService,
          ),
          voiceCallRingtonePlayerFactoryProvider.overrideWith(
            (ref) => _FakeVoiceCallRingtonePlayer.new,
          ),
        ],
      );
      addTearDown(() async {
        await container.read(voiceCallSessionProvider.notifier).endCall();
        container.dispose();
        await Future<void>.delayed(Duration.zero);
      });

      final notifier = container.read(voiceCallSessionProvider.notifier);
      await container.read(profileDetailProvider.future);
      await notifier.initialize(
        const VoiceCallSessionRequest(
          scenarioId: 'scenario-1',
          characterId: 'char-1',
          characterName: '하루',
        ),
      );

      notifier.state = container.read(voiceCallSessionProvider).copyWith(
            callDurationSeconds: 20,
          );

      final result = await notifier.endCall();

      expect(liveService.endCalls, 1);
      expect(result.analysisRequest, isNotNull);
      expect(result.analysisRequest!.durationSeconds, 20);
      expect(result.analysisRequest!.characterId, 'char-1');
      expect(result.analysisRequest!.scenarioId, 'scenario-1');
      expect(result.analysisRequest!.transcript, hasLength(2));
    });

    test('retry reuses the stored request after an error', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final firstService = _FakeGeminiLiveService();
      final secondService = _FakeGeminiLiveService();
      var factoryCalls = 0;
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWith((ref) => prefs),
          profileDetailProvider.overrideWith(
            (ref) => Future.value(_profileDetail()),
          ),
          voiceCallBootstrapServiceProvider.overrideWith(
            (ref) => _FakeVoiceCallBootstrapService(),
          ),
          voiceCallLiveServiceFactoryProvider.overrideWith(
            (ref) => (_, __) {
              factoryCalls++;
              return factoryCalls == 1 ? firstService : secondService;
            },
          ),
          voiceCallRingtonePlayerFactoryProvider.overrideWith(
            (ref) => _FakeVoiceCallRingtonePlayer.new,
          ),
        ],
      );
      addTearDown(() async {
        await container.read(voiceCallSessionProvider.notifier).endCall();
        container.dispose();
        await Future<void>.delayed(Duration.zero);
      });

      final notifier = container.read(voiceCallSessionProvider.notifier);
      await container.read(profileDetailProvider.future);
      await notifier.initialize(
        const VoiceCallSessionRequest(characterId: 'char-1'),
      );

      firstService.emitState(GeminiLiveState.error);
      await notifier.retry();

      expect(factoryCalls, 2);
      expect(firstService.disposed, isTrue);
      expect(secondService.startCalls, 1);
      expect(container.read(voiceCallSessionProvider).status,
          VoiceCallStatus.connected);
    });
  });
}

class _FakeVoiceCallBootstrapService extends VoiceCallBootstrapService {
  _FakeVoiceCallBootstrapService({
    this.token = 'token',
    this.model = 'gemini-live',
  }) : super(_UnusedChatRepository());

  final String token;
  final String model;

  int prepareCalls = 0;
  VoiceCallBootstrapInput? lastInput;

  @override
  Future<VoiceCallBootstrapData> prepare(VoiceCallBootstrapInput input) async {
    prepareCalls++;
    lastInput = input;
    return VoiceCallBootstrapData(
      wsUri: 'wss://example.com/live',
      token: token,
      model: model,
      userNickname: input.userNickname,
      jlptLevel: input.jlptLevel,
      silenceDurationMs: input.callSettings.silenceDurationMs,
      subtitleEnabled: input.callSettings.subtitleEnabled,
      voiceName: 'Kore',
      systemInstruction: 'friendly',
    );
  }
}

class _UnusedChatRepository extends ChatRepository {}

class _FakeGeminiLiveService extends GeminiLiveService {
  _FakeGeminiLiveService()
      : super(
          wsUri: 'wss://example.com/live',
          token: 'token',
          model: 'gemini-live',
        );

  int startCalls = 0;
  int endCalls = 0;
  bool disposed = false;
  List<TranscriptEntry> providedTranscript = const [];

  @override
  List<TranscriptEntry> get transcript => List.unmodifiable(providedTranscript);

  @override
  Future<void> start() async {
    startCalls++;
    onStateChange?.call(GeminiLiveState.connected);
  }

  @override
  Future<void> end() async {
    endCalls++;
    onStateChange?.call(GeminiLiveState.ended);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }

  void emitState(GeminiLiveState state) {
    onStateChange?.call(state);
  }

  void emitAiText(String text) {
    onAiTextDelta?.call(text);
  }

  void emitTranscriptEntry(TranscriptEntry entry) {
    onTranscriptEntry?.call(entry);
  }
}

class _FakeVoiceCallRingtonePlayer implements VoiceCallRingtonePlayer {
  bool started = false;
  bool stopped = false;
  bool disposed = false;

  @override
  Future<void> startLoop() async {
    started = true;
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

ProfileDetailModel _profileDetail({
  CallSettings callSettings = const CallSettings(),
}) {
  return ProfileDetailModel(
    profile: ProfileInfo(
      id: 'profile-1',
      nickname: 'Tester',
      jlptLevel: 'N5',
      dailyGoal: 10,
      experiencePoints: 0,
      level: 1,
      levelProgress: const LevelProgress(currentXp: 0, xpForNext: 100),
      streakCount: 0,
      longestStreak: 0,
      showKana: true,
      callSettings: callSettings,
      createdAt: '2026-03-24T00:00:00Z',
    ),
    summary: const ProfileSummary(
      totalWordsStudied: 0,
      totalQuizzesCompleted: 0,
      totalStudyDays: 0,
      totalXpEarned: 0,
    ),
    achievements: [],
  );
}
