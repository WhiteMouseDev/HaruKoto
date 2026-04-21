import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/chat_repository.dart';
import 'package:harukoto_mobile/features/chat/data/models/character_model.dart';
import 'package:harukoto_mobile/features/chat/data/voice_call_character_voice_context_loader.dart';

void main() {
  group('VoiceCallCharacterVoiceContextLoader', () {
    test('returns empty context without fetching when character id is absent',
        () async {
      final repository = _FakeChatRepository();
      final loader = VoiceCallCharacterVoiceContextLoader(repository);

      final context = await loader.load(null);

      expect(repository.detailCalls, 0);
      expect(context.voiceName, isNull);
      expect(context.systemInstruction, isNull);
    });

    test('maps character voice fields from detail response', () async {
      final repository = _FakeChatRepository(
        detail: const CharacterDetail(
          id: 'char-1',
          name: 'Haru',
          nameJa: 'ハル',
          personality: 'friendly',
          voiceName: 'Kore',
          targetLevel: 'N5',
          speechStyle: 'casual',
          relationship: 'friend',
        ),
      );
      final loader = VoiceCallCharacterVoiceContextLoader(repository);

      final context = await loader.load('char-1');

      expect(repository.lastCharacterId, 'char-1');
      expect(context.voiceName, 'Kore');
      expect(context.systemInstruction, 'friendly');
    });

    test('falls back to empty context when detail fetch fails', () async {
      final repository = _FakeChatRepository(error: StateError('boom'));
      final loader = VoiceCallCharacterVoiceContextLoader(repository);

      final context = await loader.load('char-1');

      expect(repository.detailCalls, 1);
      expect(context.voiceName, isNull);
      expect(context.systemInstruction, isNull);
    });
  });
}

class _FakeChatRepository extends ChatRepository {
  _FakeChatRepository({
    this.detail,
    this.error,
  });

  final CharacterDetail? detail;
  final Object? error;
  int detailCalls = 0;
  String? lastCharacterId;

  @override
  Future<CharacterDetail> fetchCharacterDetail(String characterId) async {
    detailCalls++;
    lastCharacterId = characterId;

    final fetchError = error;
    if (fetchError != null) throw fetchError;

    return detail ??
        const CharacterDetail(
          id: 'char-1',
          name: 'Haru',
          nameJa: 'ハル',
          targetLevel: 'N5',
          speechStyle: 'casual',
          relationship: 'friend',
        );
  }
}
