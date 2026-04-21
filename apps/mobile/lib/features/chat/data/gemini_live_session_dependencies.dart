import 'gemini_live_audio_adapter.dart';
import 'gemini_live_lifecycle_controller.dart';
import 'gemini_live_message_handler.dart';
import 'gemini_live_outbound_sender.dart';
import 'gemini_live_prompt_builder.dart';
import 'gemini_live_reconnect_coordinator.dart';
import 'gemini_live_transport.dart';

class GeminiLiveSessionDependencies {
  const GeminiLiveSessionDependencies({
    required this.lifecycleController,
    required this.audioAdapter,
    required this.messageHandler,
    required this.promptBuilder,
    required this.reconnectCoordinator,
    required this.transport,
    required this.outboundSender,
  });

  final GeminiLiveLifecycleController lifecycleController;
  final GeminiLiveAudioAdapter audioAdapter;
  final GeminiLiveMessageHandler messageHandler;
  final GeminiLivePromptBuilder promptBuilder;
  final GeminiLiveReconnectCoordinator reconnectCoordinator;
  final GeminiLiveTransport transport;
  final GeminiLiveOutboundSender outboundSender;
}

class GeminiLiveSessionDependenciesFactory {
  const GeminiLiveSessionDependenciesFactory();

  GeminiLiveSessionDependencies build({
    required String jlptLevel,
    String? systemInstruction,
    GeminiLiveAudioAdapter? audioAdapter,
    GeminiLiveMessageHandler? messageHandler,
    GeminiLivePromptBuilder? promptBuilder,
    GeminiLiveReconnectCoordinator? reconnectCoordinator,
    GeminiLiveLifecycleController? lifecycleController,
    GeminiLiveTransport? transport,
  }) {
    final liveTransport = transport ?? DefaultGeminiLiveTransport();

    return GeminiLiveSessionDependencies(
      lifecycleController:
          lifecycleController ?? GeminiLiveLifecycleController(),
      audioAdapter: audioAdapter ?? DefaultGeminiLiveAudioAdapter(),
      messageHandler: messageHandler ?? GeminiLiveMessageHandler(),
      promptBuilder: promptBuilder ??
          GeminiLivePromptBuilder(
            jlptLevel: jlptLevel,
            systemInstruction: systemInstruction,
          ),
      reconnectCoordinator:
          reconnectCoordinator ?? GeminiLiveReconnectCoordinator(),
      transport: liveTransport,
      outboundSender: GeminiLiveOutboundSender(
        transport: liveTransport,
      ),
    );
  }
}
