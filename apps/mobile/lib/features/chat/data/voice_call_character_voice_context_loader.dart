import 'package:flutter/foundation.dart';

import 'chat_repository.dart';

class VoiceCallCharacterVoiceContext {
  const VoiceCallCharacterVoiceContext({
    this.voiceName,
    this.systemInstruction,
  });

  static const empty = VoiceCallCharacterVoiceContext();

  final String? voiceName;
  final String? systemInstruction;
}

class VoiceCallCharacterVoiceContextLoader {
  const VoiceCallCharacterVoiceContextLoader(this._repository);

  final ChatRepository _repository;

  Future<VoiceCallCharacterVoiceContext> load(String? characterId) async {
    if (characterId == null) return VoiceCallCharacterVoiceContext.empty;

    try {
      final detail = await _repository.fetchCharacterDetail(characterId);
      return VoiceCallCharacterVoiceContext(
        voiceName: detail.voiceName,
        systemInstruction: detail.personality,
      );
    } catch (e) {
      debugPrint('[VoiceCallBootstrap] Character detail fetch failed: $e');
      return VoiceCallCharacterVoiceContext.empty;
    }
  }
}
