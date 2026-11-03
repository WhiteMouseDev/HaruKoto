import '../../../core/settings/call_settings.dart';
import '../../../core/network/api_exception.dart';
import 'chat_repository.dart';
import 'voice_call_character_voice_context_loader.dart';

class VoiceCallBootstrapInput {
  const VoiceCallBootstrapInput({
    required this.characterId,
    this.scenarioId,
    this.conversationId,
    this.onSessionPrepared,
    this.isCancelled,
    required this.callSettings,
    required this.userNickname,
    required this.jlptLevel,
  });

  final String? characterId;
  final String? scenarioId;
  final String? conversationId;
  final void Function(String)? onSessionPrepared;
  final bool Function()? isCancelled;
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
    this.scenarioGreeting,
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
  final String? scenarioGreeting;
}

class VoiceCallBootstrapService {
  VoiceCallBootstrapService(
    this._repository, {
    VoiceCallCharacterVoiceContextLoader? characterContextLoader,
  }) : _characterContextLoader = characterContextLoader ??
            VoiceCallCharacterVoiceContextLoader(_repository);

  final ChatRepository _repository;
  final VoiceCallCharacterVoiceContextLoader _characterContextLoader;

  Future<VoiceCallBootstrapData> prepare(VoiceCallBootstrapInput input) async {
    final conversationId = input.conversationId;
    if (input.isCancelled?.call() ?? false) {
      throw const ApiException(message: '통화 준비를 취소했어요.');
    }
    if (conversationId != null) {
      await _repository.createLiveSession(
        conversationId: conversationId,
        scenarioId: input.scenarioId,
        characterId: input.characterId,
      );
      input.onSessionPrepared?.call(conversationId);
      await _closeIfCancelled(input);
    }
    final tokenResp = await _repository.fetchLiveToken(
      characterId: input.characterId,
      scenarioId: input.scenarioId,
      conversationId: conversationId,
    );
    await _closeIfCancelled(input);
    if (input.scenarioId != null &&
        (tokenResp.systemInstruction?.trim().isEmpty ?? true)) {
      throw const ApiException(message: '회화 연습을 준비하지 못했어요. 잠시 후 다시 시도해 주세요.');
    }
    final characterContext =
        await _characterContextLoader.load(input.characterId);
    await _closeIfCancelled(input);
    final userNickname = _preferTokenValue(
      tokenResp.userNickname,
      fallback: input.userNickname,
    );
    final jlptLevel = _preferTokenValue(
      tokenResp.jlptLevel,
      fallback: input.jlptLevel,
    );

    return VoiceCallBootstrapData(
      wsUri: tokenResp.wsUri,
      token: tokenResp.token,
      model: tokenResp.model,
      voiceName: characterContext.voiceName,
      systemInstruction:
          tokenResp.systemInstruction ?? characterContext.systemInstruction,
      scenarioGreeting: tokenResp.scenarioGreeting,
      userNickname: userNickname,
      silenceDurationMs: input.callSettings.silenceDurationMs,
      subtitleEnabled: input.callSettings.subtitleEnabled,
      jlptLevel: jlptLevel,
    );
  }

  Future<void> _closeIfCancelled(VoiceCallBootstrapInput input) async {
    if (!(input.isCancelled?.call() ?? false)) return;
    final id = input.conversationId;
    if (id != null) {
      try {
        await _repository
            .sendLiveFeedback(
              conversationId: id,
              transcript: const [],
              durationSeconds: 0,
              analysisEnabled: false,
            )
            .timeout(const Duration(seconds: 5));
      } catch (_) {
        // The retained prepared id remains recoverable from conversation history.
      }
    }
    throw const ApiException(message: '통화 준비를 취소했어요.');
  }

  String _preferTokenValue(String? value, {required String fallback}) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }
}
