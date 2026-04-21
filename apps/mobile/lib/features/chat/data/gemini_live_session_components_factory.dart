import 'gemini_live_audio_adapter.dart';
import 'gemini_live_audio_session.dart';
import 'gemini_live_greeting_sender.dart';
import 'gemini_live_lifecycle_controller.dart';
import 'gemini_live_outbound_sender.dart';
import 'gemini_live_prompt_builder.dart';
import 'gemini_live_setup_sender.dart';
import 'gemini_live_transport.dart';

class GeminiLiveSessionComponents {
  const GeminiLiveSessionComponents({
    required this.setupSender,
    required this.greetingSender,
    required this.audioSession,
  });

  final GeminiLiveSetupSender setupSender;
  final GeminiLiveGreetingSender greetingSender;
  final GeminiLiveAudioSession audioSession;
}

class GeminiLiveSessionComponentsFactory {
  const GeminiLiveSessionComponentsFactory();

  GeminiLiveSessionComponents build({
    required String model,
    required String userNickname,
    required int silenceDurationMs,
    required GeminiLiveAudioAdapter audioAdapter,
    required GeminiLiveOutboundSender outboundSender,
    required GeminiLivePromptBuilder promptBuilder,
    required GeminiLiveLifecycleController lifecycleController,
    required GeminiLiveTransport transport,
    required void Function(String message) emitError,
    required void Function() emitAudioUnavailable,
    String? voiceName,
    String? characterName,
    String? scenarioGreeting,
  }) {
    return GeminiLiveSessionComponents(
      setupSender: GeminiLiveSetupSender(
        outboundSender: outboundSender,
        promptBuilder: promptBuilder,
        model: model,
        voiceName: voiceName,
        userNickname: userNickname,
        silenceDurationMs: silenceDurationMs,
      ),
      greetingSender: GeminiLiveGreetingSender(
        outboundSender: outboundSender,
        characterName: characterName,
        scenarioGreeting: scenarioGreeting,
      ),
      audioSession: GeminiLiveAudioSession(
        audioAdapter: audioAdapter,
        outboundSender: outboundSender,
        isActive: () => lifecycleController.isActive,
        isTransportConnected: () => transport.isConnected,
        isMuted: () => lifecycleController.isMuted,
        onError: emitError,
        onUnavailable: emitAudioUnavailable,
      ),
    );
  }
}
