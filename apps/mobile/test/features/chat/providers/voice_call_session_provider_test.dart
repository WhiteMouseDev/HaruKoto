import 'dart:async';

import 'package:harukoto_mobile/core/auth/current_account_provider.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/providers/shared_preferences_provider.dart';
import 'package:harukoto_mobile/core/settings/call_settings.dart';
import 'package:harukoto_mobile/core/providers/user_preferences_provider.dart';
import 'package:harukoto_mobile/core/settings/user_preferences.dart';
import 'package:harukoto_mobile/features/chat/data/chat_repository.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_service.dart';
import 'package:harukoto_mobile/features/chat/data/voice_call_bootstrap_service.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_microphone_permission.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_provider.dart';
import 'package:harukoto_mobile/features/my/data/models/profile_detail_model.dart';
import 'package:harukoto_mobile/features/my/providers/my_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('VoiceCallSessionController', () {
    test('a previous generation cannot change a reused notifier call',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final services = <_FakeGeminiLiveService>[];
      final container = ProviderContainer(overrides: [
        currentAccountIdProvider.overrideWithValue('test-account'),
        currentAccountReaderProvider.overrideWithValue(() => 'test-account'),
        sharedPreferencesProvider.overrideWith((ref) => prefs),
        voiceCallMicrophonePermissionRequesterProvider
            .overrideWith((ref) => allowVoiceCallMicrophonePermission),
        profileDetailProvider
            .overrideWith((ref) => Future.value(_profileDetail())),
        voiceCallBootstrapServiceProvider
            .overrideWith((ref) => _FakeVoiceCallBootstrapService()),
        voiceCallLiveServiceFactoryProvider.overrideWith((ref) => (_, __) {
              final service = _FakeGeminiLiveService();
              services.add(service);
              return service;
            }),
        voiceCallRingtonePlayerFactoryProvider
            .overrideWith((ref) => _FakeVoiceCallRingtonePlayer.new),
      ]);
      addTearDown(container.dispose);
      await container.read(profileDetailProvider.future);
      final controller = container.read(voiceCallSessionProvider.notifier);
      await controller
          .initialize(const VoiceCallSessionRequest(characterId: 'first'));
      await controller
          .initialize(const VoiceCallSessionRequest(characterId: 'second'));

      services.first.emitState(GeminiLiveState.error);
      services.first.emitAiText('old generation');
      services.first.onMicrophoneInterrupted?.call();
      expect(container.read(voiceCallSessionProvider).isConnected, isTrue);
      expect(container.read(voiceCallSessionProvider).currentAiText, isEmpty);
      expect(container.read(voiceCallSessionProvider).microphoneInterrupted,
          isFalse);
      expect(services.first.disposed, isTrue);
      expect(services.last.disposed, isFalse);
      await controller.endCall();
    });

    for (final foregroundBeforeConnect in [false, true]) {
      test(
          'connection completion honors current foreground state ($foregroundBeforeConnect)',
          () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final release = Completer<void>();
        final bootstrap = _FakeVoiceCallBootstrapService()
          ..blocker = release.future;
        final service = _FakeGeminiLiveService();
        final container = ProviderContainer(overrides: [
          currentAccountIdProvider.overrideWithValue('test-account'),
          currentAccountReaderProvider.overrideWithValue(() => 'test-account'),
          sharedPreferencesProvider.overrideWith((ref) => prefs),
          voiceCallMicrophonePermissionRequesterProvider
              .overrideWith((ref) => allowVoiceCallMicrophonePermission),
          profileDetailProvider
              .overrideWith((ref) => Future.value(_profileDetail())),
          voiceCallBootstrapServiceProvider.overrideWith((ref) => bootstrap),
          voiceCallLiveServiceFactoryProvider
              .overrideWith((ref) => (_, __) => service),
          voiceCallRingtonePlayerFactoryProvider
              .overrideWith((ref) => _FakeVoiceCallRingtonePlayer.new),
        ]);
        addTearDown(container.dispose);
        await container.read(profileDetailProvider.future);
        final controller = container.read(voiceCallSessionProvider.notifier);
        final starting = controller
            .initialize(const VoiceCallSessionRequest(characterId: 'char-1'));
        await bootstrap.entered.future;
        controller.setAppActive(false);
        if (foregroundBeforeConnect) controller.setAppActive(true);
        release.complete();
        await starting;
        expect(service.suspendMicrophoneCalls, foregroundBeforeConnect ? 0 : 1);
        expect(container.read(voiceCallSessionProvider).microphoneInterrupted,
            !foregroundBeforeConnect);
        expect(service.resumeMicrophoneCalls, 0);
        await controller.endCall();
      });
    }

    for (final initiallyMuted in [false, true]) {
      test(
          'microphone recovery is explicit and preserves mute ($initiallyMuted)',
          () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final service = _FakeGeminiLiveService();
        final container = ProviderContainer(overrides: [
          currentAccountIdProvider.overrideWithValue('test-account'),
          currentAccountReaderProvider.overrideWithValue(() => 'test-account'),
          sharedPreferencesProvider.overrideWith((ref) => prefs),
          voiceCallMicrophonePermissionRequesterProvider
              .overrideWith((ref) => allowVoiceCallMicrophonePermission),
          profileDetailProvider
              .overrideWith((ref) => Future.value(_profileDetail())),
          voiceCallBootstrapServiceProvider
              .overrideWith((ref) => _FakeVoiceCallBootstrapService()),
          voiceCallLiveServiceFactoryProvider
              .overrideWith((ref) => (_, __) => service),
          voiceCallRingtonePlayerFactoryProvider
              .overrideWith((ref) => _FakeVoiceCallRingtonePlayer.new),
        ]);
        addTearDown(container.dispose);
        await container.read(profileDetailProvider.future);
        final controller = container.read(voiceCallSessionProvider.notifier);
        await controller
            .initialize(const VoiceCallSessionRequest(characterId: 'char-1'));
        controller.setMuted(initiallyMuted);
        service.onMicrophoneInterrupted?.call();
        expect(
            container.read(voiceCallSessionProvider).statusLabel, '마이크 일시중지');
        controller.setAppActive(false);
        expect(service.suspendMicrophoneCalls, 1);
        expect(await controller.resumeMicrophone(), isFalse);
        expect(service.resumeMicrophoneCalls, 0);
        controller.setAppActive(true);
        expect(service.resumeMicrophoneCalls, 0);
        expect(await controller.resumeMicrophone(), isTrue);
        expect(container.read(voiceCallSessionProvider).microphoneInterrupted,
            isFalse);
        expect(
            container.read(voiceCallSessionProvider).isMuted, initiallyMuted);
        expect(service.isMuted, initiallyMuted);

        service.emitState(GeminiLiveState.connecting);
        controller.setAppActive(false);
        expect(service.suspendMicrophoneCalls, 2);
        expect(container.read(voiceCallSessionProvider).microphoneInterrupted,
            isTrue);
        controller.setAppActive(true);
        service.emitState(GeminiLiveState.connected);
        expect(service.resumeMicrophoneCalls, 1);
        expect(await controller.resumeMicrophone(), isTrue);

        service.onMicrophoneInterrupted?.call();
        final release = Completer<bool>();
        service.resumeMicrophoneBlocker = release.future;
        final pendingResume = controller.resumeMicrophone();
        expect(await controller.resumeMicrophone(), isFalse);
        controller.setAppActive(false);
        release.complete(true);
        expect(await pendingResume, isFalse);
        expect(container.read(voiceCallSessionProvider).microphoneInterrupted,
            isTrue);
        expect(container.read(voiceCallSessionProvider).resumingMicrophone,
            isFalse);

        controller.setAppActive(true);
        final networkRelease = Completer<bool>();
        service.resumeMicrophoneBlocker = networkRelease.future;
        final networkResume = controller.resumeMicrophone();
        service.emitState(GeminiLiveState.connecting);
        expect(container.read(voiceCallSessionProvider).resumingMicrophone,
            isFalse);
        service.emitState(GeminiLiveState.connected);
        networkRelease.complete(true);
        expect(await networkResume, isFalse);
        expect(container.read(voiceCallSessionProvider).microphoneInterrupted,
            isTrue);
        expect(container.read(voiceCallSessionProvider).resumingMicrophone,
            isFalse);
        service.resumeMicrophoneBlocker = null;
        expect(await controller.resumeMicrophone(), isTrue);
        service.onMicrophoneInterrupted?.call();

        final endingRelease = Completer<bool>();
        service.resumeMicrophoneBlocker = endingRelease.future;
        final endingResume = controller.resumeMicrophone();
        await controller.endCall();
        endingRelease.complete(true);
        expect(await endingResume, isFalse);
        expect(container.read(voiceCallSessionProvider).status,
            VoiceCallStatus.ending);
      });
    }

    test('a second call connects after the retained provider is invalidated',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final bootstrap = _FakeVoiceCallBootstrapService();
      final services = <_FakeGeminiLiveService>[];
      final ringtones = <_FakeVoiceCallRingtonePlayer>[];
      final container = ProviderContainer(overrides: [
        currentAccountIdProvider.overrideWithValue('test-account'),
        currentAccountReaderProvider.overrideWithValue(() => 'test-account'),
        sharedPreferencesProvider.overrideWith((ref) => prefs),
        voiceCallMicrophonePermissionRequesterProvider
            .overrideWith((ref) => allowVoiceCallMicrophonePermission),
        profileDetailProvider
            .overrideWith((ref) => Future.value(_profileDetail())),
        voiceCallBootstrapServiceProvider.overrideWith((ref) => bootstrap),
        voiceCallLiveServiceFactoryProvider.overrideWith((ref) => (_, __) {
              final service = _FakeGeminiLiveService();
              services.add(service);
              return service;
            }),
        voiceCallRingtonePlayerFactoryProvider.overrideWith((ref) => () {
              final ringtone = _FakeVoiceCallRingtonePlayer();
              ringtones.add(ringtone);
              return ringtone;
            }),
      ]);
      addTearDown(container.dispose);
      final subscription =
          container.listen(voiceCallSessionProvider, (_, __) {});
      addTearDown(subscription.close);
      await container.read(profileDetailProvider.future);
      final first = container.read(voiceCallSessionProvider.notifier);
      await first
          .initialize(const VoiceCallSessionRequest(characterId: 'char-1'));
      await first.endCall();
      container.invalidate(voiceCallSessionProvider);
      final second = container.read(voiceCallSessionProvider.notifier);
      expect(identical(first, second), isTrue);
      await second
          .initialize(const VoiceCallSessionRequest(characterId: 'char-2'));

      expect(bootstrap.prepareCalls, 2);
      expect(services.last.startCalls, 1);
      expect(container.read(voiceCallSessionProvider).isConnected, isTrue);
      expect(ringtones, hasLength(2));
      expect(ringtones.first.disposed, isTrue);
      expect(ringtones.last.disposed, isFalse);
      services.first.emitState(GeminiLiveState.error);
      services.first.emitAiText('stale caption');
      services.first.onMicrophoneInterrupted?.call();
      expect(container.read(voiceCallSessionProvider).isConnected, isTrue);
      expect(container.read(voiceCallSessionProvider).currentAiText, isEmpty);
      expect(container.read(voiceCallSessionProvider).microphoneInterrupted,
          isFalse);
      await second.endCall();
    });

    test('an old pending start and end cannot mutate the rebuilt call',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final release = Completer<void>();
      final bootstrap = _FakeVoiceCallBootstrapService()
        ..blocker = release.future;
      final oldService = _FakeGeminiLiveService();
      final newService = _FakeGeminiLiveService();
      final container = ProviderContainer(overrides: [
        currentAccountIdProvider.overrideWithValue('test-account'),
        currentAccountReaderProvider.overrideWithValue(() => 'test-account'),
        sharedPreferencesProvider.overrideWith((ref) => prefs),
        voiceCallMicrophonePermissionRequesterProvider
            .overrideWith((ref) => allowVoiceCallMicrophonePermission),
        profileDetailProvider
            .overrideWith((ref) => Future.value(_profileDetail())),
        voiceCallBootstrapServiceProvider.overrideWith((ref) => bootstrap),
        voiceCallLiveServiceFactoryProvider.overrideWith((ref) =>
            (_, request) =>
                request.characterId == 'old' ? oldService : newService),
        voiceCallRingtonePlayerFactoryProvider
            .overrideWith((ref) => _FakeVoiceCallRingtonePlayer.new),
      ]);
      addTearDown(container.dispose);
      final subscription =
          container.listen(voiceCallSessionProvider, (_, __) {});
      addTearDown(subscription.close);
      await container.read(profileDetailProvider.future);
      final controller = container.read(voiceCallSessionProvider.notifier);
      final oldStart = controller
          .initialize(const VoiceCallSessionRequest(characterId: 'old'));
      await bootstrap.entered.future;
      final oldEnd = controller.endCall();
      container.invalidate(voiceCallSessionProvider);
      bootstrap.blocker = null;
      final rebuilt = container.read(voiceCallSessionProvider.notifier);
      await rebuilt
          .initialize(const VoiceCallSessionRequest(characterId: 'new'));
      release.complete();
      await oldStart;
      expect((await oldEnd).ignored, isTrue);
      expect(oldService.startCalls, 0);
      expect(oldService.disposed, isTrue);
      expect(newService.startCalls, 1);
      expect(newService.disposed, isFalse);
      expect(newService.endCalls, 0);
      expect(newService.isMuted, isFalse);
      expect(container.read(voiceCallSessionProvider).isConnected, isTrue);
      await rebuilt.endCall();
    });

    test('ending during bootstrap prevents a late service from starting',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final bootstrap = _FakeVoiceCallBootstrapService();
      final release = Completer<void>();
      bootstrap.blocker = release.future;
      final service = _FakeGeminiLiveService();
      final container = ProviderContainer(overrides: [
        currentAccountIdProvider.overrideWithValue('test-account'),
        currentAccountReaderProvider.overrideWithValue(() => 'test-account'),
        sharedPreferencesProvider.overrideWith((ref) => prefs),
        voiceCallMicrophonePermissionRequesterProvider
            .overrideWith((ref) => allowVoiceCallMicrophonePermission),
        profileDetailProvider
            .overrideWith((ref) => Future.value(_profileDetail())),
        voiceCallBootstrapServiceProvider.overrideWith((ref) => bootstrap),
        voiceCallLiveServiceFactoryProvider
            .overrideWith((ref) => (_, __) => service),
        voiceCallRingtonePlayerFactoryProvider
            .overrideWith((ref) => _FakeVoiceCallRingtonePlayer.new),
      ]);
      addTearDown(container.dispose);
      await container.read(profileDetailProvider.future);
      final controller = container.read(voiceCallSessionProvider.notifier);
      final starting = controller
          .initialize(const VoiceCallSessionRequest(characterId: 'char-1'));
      await bootstrap.entered.future;
      final ending = controller.endCall();
      release.complete();
      await starting;
      final result = await ending;
      expect(service.startCalls, 0);
      expect(service.disposed, isTrue);
      expect(result.analysisRequest?.conversationId,
          bootstrap.lastInput?.conversationId);
      expect(result.analysisRequest?.durationSeconds, 0);
      expect(result.analysisRequest?.analysisEnabled, isFalse);
      expect(result.analysisRequest?.wasConnected, isFalse);
    });

    test('ending has a bounded wait when bootstrap remains pending', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final bootstrap = _FakeVoiceCallBootstrapService();
      final release = Completer<void>();
      bootstrap.blocker = release.future;
      final service = _FakeGeminiLiveService();
      final container = ProviderContainer(overrides: [
        currentAccountIdProvider.overrideWithValue('test-account'),
        currentAccountReaderProvider.overrideWithValue(() => 'test-account'),
        sharedPreferencesProvider.overrideWith((ref) => prefs),
        voiceCallMicrophonePermissionRequesterProvider
            .overrideWith((ref) => allowVoiceCallMicrophonePermission),
        profileDetailProvider
            .overrideWith((ref) => Future.value(_profileDetail())),
        voiceCallBootstrapServiceProvider.overrideWith((ref) => bootstrap),
        voiceCallLiveServiceFactoryProvider
            .overrideWith((ref) => (_, __) => service),
        voiceCallRingtonePlayerFactoryProvider
            .overrideWith((ref) => _FakeVoiceCallRingtonePlayer.new),
      ]);
      addTearDown(container.dispose);
      await container.read(profileDetailProvider.future);
      final controller = container.read(voiceCallSessionProvider.notifier);
      final starting = controller
          .initialize(const VoiceCallSessionRequest(characterId: 'char-1'));
      await bootstrap.entered.future;
      final ending = controller.endCall();
      final result = await ending.timeout(const Duration(seconds: 3));
      expect(result.analysisRequest, isNull);
      release.complete();
      await starting;
      expect(service.startCalls, 0);
      expect(service.disposed, isTrue);
    });

    test('initializes and reacts to live service callbacks', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final bootstrap = _FakeVoiceCallBootstrapService();
      final liveService = _FakeGeminiLiveService();
      final container = ProviderContainer(
        overrides: [
          currentAccountIdProvider.overrideWithValue('test-account'),
          currentAccountReaderProvider.overrideWithValue(() => 'test-account'),
          sharedPreferencesProvider.overrideWith((ref) => prefs),
          voiceCallMicrophonePermissionRequesterProvider.overrideWith(
            (ref) => allowVoiceCallMicrophonePermission,
          ),
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
      expect(state.currentAiText, 'こんにちは');
    });

    test('toggle controls update local state and live service mute state',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final liveService = _FakeGeminiLiveService();
      final container = ProviderContainer(
        overrides: [
          currentAccountIdProvider.overrideWithValue('test-account'),
          currentAccountReaderProvider.overrideWithValue(() => 'test-account'),
          sharedPreferencesProvider.overrideWith((ref) => prefs),
          voiceCallMicrophonePermissionRequesterProvider.overrideWith(
            (ref) => allowVoiceCallMicrophonePermission,
          ),
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
          currentAccountIdProvider.overrideWithValue('test-account'),
          currentAccountReaderProvider.overrideWithValue(() => 'test-account'),
          sharedPreferencesProvider.overrideWith((ref) => prefs),
          voiceCallMicrophonePermissionRequesterProvider.overrideWith(
            (ref) => allowVoiceCallMicrophonePermission,
          ),
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
          currentAccountIdProvider.overrideWithValue('test-account'),
          currentAccountReaderProvider.overrideWithValue(() => 'test-account'),
          sharedPreferencesProvider.overrideWith((ref) => prefs),
          voiceCallMicrophonePermissionRequesterProvider.overrideWith(
            (ref) => allowVoiceCallMicrophonePermission,
          ),
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
      final firstService = _FakeGeminiLiveService()..connectOnStart = false;
      final secondService = _FakeGeminiLiveService();
      var factoryCalls = 0;
      final container = ProviderContainer(
        overrides: [
          currentAccountIdProvider.overrideWithValue('test-account'),
          currentAccountReaderProvider.overrideWithValue(() => 'test-account'),
          sharedPreferencesProvider.overrideWith((ref) => prefs),
          voiceCallMicrophonePermissionRequesterProvider.overrideWith(
            (ref) => allowVoiceCallMicrophonePermission,
          ),
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
  Future<void>? blocker;
  final entered = Completer<void>();

  @override
  Future<VoiceCallBootstrapData> prepare(VoiceCallBootstrapInput input) async {
    prepareCalls++;
    lastInput = input;
    if (!entered.isCompleted) entered.complete();
    await blocker;
    if (input.conversationId != null) {
      input.onSessionPrepared?.call(input.conversationId!);
    }
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
  bool connectOnStart = true;
  int endCalls = 0;
  bool disposed = false;
  int suspendMicrophoneCalls = 0;
  int resumeMicrophoneCalls = 0;
  Future<bool>? resumeMicrophoneBlocker;
  List<TranscriptEntry> providedTranscript = const [];

  @override
  List<TranscriptEntry> get transcript => List.unmodifiable(providedTranscript);

  @override
  Future<void> start() async {
    startCalls++;
    onStateChange?.call(
        connectOnStart ? GeminiLiveState.connected : GeminiLiveState.error);
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

  @override
  Future<void> suspendMicrophone() async {
    suspendMicrophoneCalls++;
  }

  @override
  Future<bool> resumeMicrophone() async {
    resumeMicrophoneCalls++;
    return await resumeMicrophoneBlocker ?? true;
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
