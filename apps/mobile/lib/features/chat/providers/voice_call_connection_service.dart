import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/call_settings.dart';
import '../data/gemini_live_service.dart';
import '../data/voice_call_bootstrap_service.dart';
import 'chat_provider.dart';

class VoiceCallSessionRequest {
  const VoiceCallSessionRequest({
    this.scenarioId,
    this.characterId,
    this.characterName,
  });

  final String? scenarioId;
  final String? characterId;
  final String? characterName;
}

class VoiceCallConnectionInput {
  const VoiceCallConnectionInput({
    required this.request,
    required this.callSettings,
    required this.userNickname,
    required this.jlptLevel,
  });

  final VoiceCallSessionRequest request;
  final CallSettings callSettings;
  final String userNickname;
  final String jlptLevel;
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
    return (bootstrap, request) => GeminiLiveService(
          wsUri: bootstrap.wsUri,
          token: bootstrap.token,
          model: bootstrap.model,
          characterName: request.characterName,
          voiceName: bootstrap.voiceName,
          systemInstruction: bootstrap.systemInstruction,
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
  })  : _bootstrapService = bootstrapService,
        _liveServiceFactory = liveServiceFactory;

  final VoiceCallBootstrapService _bootstrapService;
  final VoiceCallLiveServiceFactory _liveServiceFactory;

  Future<GeminiLiveService> prepare(VoiceCallConnectionInput input) async {
    final bootstrap = await _bootstrapService.prepare(
      VoiceCallBootstrapInput(
        characterId: input.request.characterId,
        callSettings: input.callSettings,
        userNickname: input.userNickname,
        jlptLevel: input.jlptLevel,
      ),
    );

    if (bootstrap.token.isEmpty || bootstrap.model.isEmpty) {
      throw const VoiceCallConnectionException('연결에 실패했습니다');
    }

    return _liveServiceFactory(bootstrap, input.request);
  }
}

class VoiceCallConnectionException implements Exception {
  const VoiceCallConnectionException(this.message);

  final String message;
}
