import 'package:flutter/foundation.dart';

import '../../../core/settings/call_settings.dart';
import 'chat_repository.dart';

class VoiceCallBootstrapInput {
  const VoiceCallBootstrapInput({
    required this.characterId,
    required this.callSettings,
    required this.userNickname,
    required this.jlptLevel,
  });

  final String? characterId;
  final CallSettings callSettings;
  final String userNickname;
  final String jlptLevel;
}

class VoiceCallBootstrapData {
  const VoiceCallBootstrapData({
    required this.wsUri,
    required this.token,
    required this.model,
    required this.userNickname,
    required this.jlptLevel,
    required this.silenceDurationMs,
    required this.subtitleEnabled,
    this.voiceName,
    this.systemInstruction,
  });

  final String wsUri;
  final String token;
  final String model;
  final String userNickname;
  final String jlptLevel;
  final int silenceDurationMs;
  final bool subtitleEnabled;
  final String? voiceName;
  final String? systemInstruction;
}

class VoiceCallBootstrapService {
  VoiceCallBootstrapService(this._repository);

  final ChatRepository _repository;

  Future<VoiceCallBootstrapData> prepare(VoiceCallBootstrapInput input) async {
    final tokenResp = await _repository.fetchLiveToken(
      characterId: input.characterId,
    );

    String? voiceName;
    String? personality;

    if (input.characterId != null) {
      try {
        final detail =
            await _repository.fetchCharacterDetail(input.characterId!);
        voiceName = detail.voiceName;
        personality = detail.personality;
      } catch (e) {
        debugPrint('[VoiceCallBootstrap] Character detail fetch failed: $e');
      }
    }

    return VoiceCallBootstrapData(
      wsUri: tokenResp.wsUri,
      token: tokenResp.token,
      model: tokenResp.model,
      voiceName: voiceName,
      systemInstruction: personality,
      userNickname: input.userNickname,
      silenceDurationMs: input.callSettings.silenceDurationMs,
      subtitleEnabled: input.callSettings.subtitleEnabled,
      jlptLevel: input.jlptLevel,
    );
  }
}
