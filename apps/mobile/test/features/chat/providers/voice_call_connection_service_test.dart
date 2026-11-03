import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:harukoto_mobile/core/settings/call_settings.dart';
import 'package:harukoto_mobile/features/chat/data/chat_repository.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_service.dart';
import 'package:harukoto_mobile/features/chat/data/voice_call_bootstrap_service.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_connection_service.dart';
import 'package:harukoto_mobile/features/chat/providers/chat_provider.dart';

void main() {
  group('VoiceCallConnectionValidator', () {
    test('accepts complete live credentials', () {
      const validator = VoiceCallConnectionValidator();

      expect(
        () => validator.ensureReady(_bootstrap()),
        returnsNormally,
      );
    });

    test('rejects missing token or model with user-facing connection error',
        () {
      const validator = VoiceCallConnectionValidator();

      expect(
        () => validator.ensureReady(_bootstrap(token: '')),
        throwsA(isA<VoiceCallConnectionException>()),
      );
      expect(
        () => validator.ensureReady(_bootstrap(model: '')),
        throwsA(isA<VoiceCallConnectionException>()),
      );
    });
  });

  group('VoiceCallConnectionService', () {
    test('production factory passes the scenario context to the Live service',
        () {
      final container = ProviderContainer(overrides: [
        chatRepositoryProvider.overrideWith((ref) => _UnusedChatRepository())
      ]);
      addTearDown(container.dispose);
      final factory = container.read(voiceCallLiveServiceFactoryProvider);
      final service = factory(
          const VoiceCallBootstrapData(
            wsUri: 'wss://example.test/live',
            token: 'token',
            model: 'gemini-live',
            userNickname: 'Tester',
            jlptLevel: 'N5',
            silenceDurationMs: 1200,
            subtitleEnabled: true,
            systemInstruction: 'hotel role',
            scenarioGreeting: 'hotel opening',
          ),
          const VoiceCallSessionRequest(scenarioId: 'hotel-1'));
      expect(service.systemInstruction, 'hotel role');
      expect(service.scenarioGreeting, 'hotel opening');
    });

    test(
        'token refresh preserves the original session context and model configuration',
        () async {
      final repository = _TokenRepository();
      final container = ProviderContainer(overrides: [
        chatRepositoryProvider.overrideWith((ref) => repository)
      ]);
      addTearDown(container.dispose);
      final service = container.read(voiceCallLiveServiceFactoryProvider)(
        _bootstrap(),
        const VoiceCallSessionRequest(
            conversationId: 'stable-id',
            scenarioId: 'hotel-1',
            characterId: 'haru-1'),
      );
      expect(await service.refreshToken!(), 'fresh-token');
      expect(repository.ids, ['stable-id', 'hotel-1', 'haru-1']);
      expect(service.model, 'gemini-live');
      expect(service.wsUri, 'wss://example.test/live');
      expect(service.token, 'token');
      repository.token = ' ';
      await expectLater(service.refreshToken!(),
          throwsA(isA<VoiceCallConnectionException>()));
    });

    test('prepares bootstrap input and builds a live service', () async {
      final bootstrapService = _FakeVoiceCallBootstrapService();
      final builtServices = <GeminiLiveService>[];
      final service = VoiceCallConnectionService(
        bootstrapService: bootstrapService,
        liveServiceFactory: (bootstrap, request) {
          final liveService = _FakeGeminiLiveService(
            wsUri: bootstrap.wsUri,
            token: bootstrap.token,
            model: bootstrap.model,
            characterName: request.characterName,
          );
          builtServices.add(liveService);
          return liveService;
        },
      );

      final liveService = await service.prepare(
        const VoiceCallConnectionInput(
          request: VoiceCallSessionRequest(
            characterId: 'char-1',
            characterName: '하루',
            scenarioId: 'hotel-1',
          ),
          callSettings: CallSettings(silenceDurationMs: 1500),
          userNickname: 'Tester',
          jlptLevel: 'N4',
        ),
      );

      expect(bootstrapService.lastInput?.characterId, 'char-1');
      expect(bootstrapService.lastInput?.scenarioId, 'hotel-1');
      expect(bootstrapService.lastInput?.userNickname, 'Tester');
      expect(bootstrapService.lastInput?.jlptLevel, 'N4');
      expect(bootstrapService.lastInput?.callSettings.silenceDurationMs, 1500);
      expect(liveService, same(builtServices.single));
      expect((liveService as _FakeGeminiLiveService).characterName, '하루');
    });

    test('does not build a live service when credentials are incomplete',
        () async {
      var factoryCalls = 0;
      final service = VoiceCallConnectionService(
        bootstrapService: _FakeVoiceCallBootstrapService(token: ''),
        liveServiceFactory: (_, __) {
          factoryCalls++;
          return _FakeGeminiLiveService();
        },
      );

      await expectLater(
        service.prepare(
          const VoiceCallConnectionInput(
            request: VoiceCallSessionRequest(characterId: 'char-1'),
            callSettings: CallSettings(),
            userNickname: 'Tester',
            jlptLevel: 'N5',
          ),
        ),
        throwsA(isA<VoiceCallConnectionException>()),
      );
      expect(factoryCalls, 0);
    });
  });
}

VoiceCallBootstrapData _bootstrap({
  String token = 'token',
  String model = 'gemini-live',
}) {
  return VoiceCallBootstrapData(
    wsUri: 'wss://example.test/live',
    token: token,
    model: model,
    userNickname: 'Tester',
    jlptLevel: 'N5',
    silenceDurationMs: 1200,
    subtitleEnabled: true,
  );
}

class _FakeVoiceCallBootstrapService extends VoiceCallBootstrapService {
  _FakeVoiceCallBootstrapService({
    this.token = 'token',
  }) : super(_UnusedChatRepository());

  final String token;
  VoiceCallBootstrapInput? lastInput;

  @override
  Future<VoiceCallBootstrapData> prepare(VoiceCallBootstrapInput input) async {
    lastInput = input;
    return _bootstrap(token: token);
  }
}

class _FakeGeminiLiveService extends GeminiLiveService {
  _FakeGeminiLiveService({
    super.wsUri = 'wss://example.test/live',
    super.token = 'token',
    super.model = 'gemini-live',
    super.characterName,
  });
}

class _UnusedChatRepository extends ChatRepository {}

class _TokenRepository extends ChatRepository {
  String token = 'fresh-token';
  List<String?> ids = [];
  @override
  Future<LiveTokenResponse> fetchLiveToken(
      {String? characterId, String? scenarioId, String? conversationId}) async {
    ids = [conversationId, scenarioId, characterId];
    return LiveTokenResponse(
        token: token,
        wsUri: 'wss://changed.example/live',
        model: 'changed-model');
  }
}
