import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/settings/call_settings.dart';
import 'package:harukoto_mobile/features/chat/data/chat_repository.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_service.dart';
import 'package:harukoto_mobile/features/chat/data/voice_call_bootstrap_service.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_connection_service.dart';

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
          ),
          callSettings: CallSettings(silenceDurationMs: 1500),
          userNickname: 'Tester',
          jlptLevel: 'N4',
        ),
      );

      expect(bootstrapService.lastInput?.characterId, 'char-1');
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
