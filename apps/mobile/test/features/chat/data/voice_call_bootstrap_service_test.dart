import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/settings/call_settings.dart';
import 'package:harukoto_mobile/features/chat/data/chat_repository.dart';
import 'package:harukoto_mobile/features/chat/data/voice_call_bootstrap_service.dart';
import 'package:harukoto_mobile/features/chat/data/voice_call_character_voice_context_loader.dart';

void main() {
  group('VoiceCallBootstrapService', () {
    test('combines live token, user context, and character voice context',
        () async {
      final repository = _FakeChatRepository();
      final service = VoiceCallBootstrapService(
        repository,
        characterContextLoader: _FakeCharacterVoiceContextLoader(),
      );

      final bootstrap = await service.prepare(
        const VoiceCallBootstrapInput(
          characterId: 'char-1',
          callSettings: CallSettings(
            silenceDurationMs: 1500,
            subtitleEnabled: false,
          ),
          userNickname: 'Tester',
          jlptLevel: 'N4',
        ),
      );

      expect(repository.lastTokenCharacterId, 'char-1');
      expect(bootstrap.wsUri, 'wss://example.test/live');
      expect(bootstrap.token, 'token');
      expect(bootstrap.model, 'gemini-live');
      expect(bootstrap.voiceName, 'Kore');
      expect(bootstrap.systemInstruction, 'friendly');
      expect(bootstrap.userNickname, 'Tester');
      expect(bootstrap.jlptLevel, 'N4');
      expect(bootstrap.silenceDurationMs, 1500);
      expect(bootstrap.subtitleEnabled, isFalse);
    });
  });
}

class _FakeChatRepository extends ChatRepository {
  String? lastTokenCharacterId;

  @override
  Future<LiveTokenResponse> fetchLiveToken({String? characterId}) async {
    lastTokenCharacterId = characterId;
    return const LiveTokenResponse(
      wsUri: 'wss://example.test/live',
      token: 'token',
      model: 'gemini-live',
    );
  }
}

class _FakeCharacterVoiceContextLoader
    extends VoiceCallCharacterVoiceContextLoader {
  _FakeCharacterVoiceContextLoader() : super(_UnusedChatRepository());

  @override
  Future<VoiceCallCharacterVoiceContext> load(String? characterId) async {
    return const VoiceCallCharacterVoiceContext(
      voiceName: 'Kore',
      systemInstruction: 'friendly',
    );
  }
}

class _UnusedChatRepository extends ChatRepository {}
