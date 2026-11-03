import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/call_settings.dart';
import '../data/gemini_live_service.dart';
import '../data/voice_call_bootstrap_service.dart';
import 'chat_provider.dart';

class VoiceCallSessionRequest {
  const VoiceCallSessionRequest({
    this.scenarioId,
    this.conversationId,
    this.characterId,
    this.characterName,
  });

  final String? scenarioId;
  final String? conversationId;
  final String? characterId;
  final String? characterName;

  VoiceCallSessionRequest withConversationId(String id) =>
      VoiceCallSessionRequest(
        scenarioId: scenarioId,
        characterId: characterId,
        characterName: characterName,
        conversationId: id,
      );
}

class VoiceCallConnectionInput {
  const VoiceCallConnectionInput({
    required this.request,
    required this.callSettings,
    required this.userNickname,
    required this.jlptLevel,
    this.onSessionPrepared,
    this.isCancelled,
  });

  final VoiceCallSessionRequest request;
  final CallSettings callSettings;
  final String userNickname;
  final String jlptLevel;
  final void Function(String)? onSessionPrepared;
  final bool Function()? isCancelled;
}

typedef VoiceCallLiveServiceFactory = GeminiLiveService Function(
  VoiceCallBootstrapData bootstrap,
  VoiceCallSessionRequest request,
);

final voiceCallBootstrapServiceProvider = Provider<VoiceCallBootstrapService>(
  (ref) => VoiceCallBootstrapService(ref.watch(chatRepositoryProvider)),
);

final voiceCallLiveServiceFactoryProvider =
    Provider<VoiceCallLiveServiceFactory>(
  (ref) {
    final repository = ref.watch(chatRepositoryProvider);
    return (bootstrap, request) => GeminiLiveService(
          wsUri: bootstrap.wsUri,
          token: bootstrap.token,
          refreshToken: () async {
            final refreshed = await repository.fetchLiveToken(
              conversationId: request.conversationId,
              scenarioId: request.scenarioId,
              characterId: request.characterId,
            );
            if (refreshed.token.trim().isEmpty) {
              throw const VoiceCallConnectionException('연결을 갱신하지 못했어요.');
            }
            return refreshed.token;
          },
          model: bootstrap.model,
          characterName: request.characterName,
          voiceName: bootstrap.voiceName,
          systemInstruction: bootstrap.systemInstruction,
          scenarioGreeting: bootstrap.scenarioGreeting,
          userNickname: bootstrap.userNickname,
          silenceDurationMs: bootstrap.silenceDurationMs,
          jlptLevel: bootstrap.jlptLevel,
        );
  },
);

final voiceCallConnectionServiceProvider =
    Provider<VoiceCallConnectionService>((ref) {
  return VoiceCallConnectionService(
    bootstrapService: ref.watch(voiceCallBootstrapServiceProvider),
    liveServiceFactory: ref.watch(voiceCallLiveServiceFactoryProvider),
  );
});

class VoiceCallConnectionService {
  const VoiceCallConnectionService({
    required VoiceCallBootstrapService bootstrapService,
    required VoiceCallLiveServiceFactory liveServiceFactory,
    VoiceCallConnectionValidator validator =
        const VoiceCallConnectionValidator(),
  })  : _bootstrapService = bootstrapService,
        _validator = validator,
        _liveServiceFactory = liveServiceFactory;

  final VoiceCallBootstrapService _bootstrapService;
  final VoiceCallConnectionValidator _validator;
  final VoiceCallLiveServiceFactory _liveServiceFactory;

  Future<GeminiLiveService> prepare(VoiceCallConnectionInput input) async {
    final bootstrap = await _bootstrapService.prepare(
      VoiceCallBootstrapInput(
        characterId: input.request.characterId,
        scenarioId: input.request.scenarioId,
        conversationId: input.request.conversationId,
        onSessionPrepared: input.onSessionPrepared,
        isCancelled: input.isCancelled,
        callSettings: input.callSettings,
        userNickname: input.userNickname,
        jlptLevel: input.jlptLevel,
      ),
    );

    _validator.ensureReady(bootstrap);
    return _liveServiceFactory(bootstrap, input.request);
  }
}

class VoiceCallConnectionValidator {
  const VoiceCallConnectionValidator();

  void ensureReady(VoiceCallBootstrapData bootstrap) {
    if (bootstrap.token.isEmpty || bootstrap.model.isEmpty) {
      throw const VoiceCallConnectionException('연결에 실패했습니다');
    }
  }
}

class VoiceCallConnectionException implements Exception {
  const VoiceCallConnectionException(this.message);

  final String message;
}
