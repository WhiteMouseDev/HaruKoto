import 'gemini_live_audio_adapter.dart';
import 'gemini_live_events.dart';
import 'gemini_live_lifecycle_controller.dart';
import 'gemini_live_message_handler.dart';
import 'gemini_live_outbound_sender.dart';
import 'gemini_live_prompt_builder.dart';
import 'gemini_live_reconnect_coordinator.dart';
import 'gemini_live_session_components_factory.dart';
import 'gemini_live_session_lifecycle_runner.dart';
import 'gemini_live_session_lifecycle_runner_factory.dart';
import 'gemini_live_session_runtime_factory.dart';
import 'gemini_live_transcript.dart';
import 'gemini_live_transcript_emitter.dart';
import 'gemini_live_transport.dart';

class GeminiLiveServiceSession {
  const GeminiLiveServiceSession({
    required this.lifecycleController,
    required this.transcriptEmitter,
    required this.lifecycleRunner,
  });

  final GeminiLiveLifecycleController lifecycleController;
  final GeminiLiveTranscriptEmitter transcriptEmitter;
  final GeminiLiveSessionLifecycleRunner lifecycleRunner;
}

class GeminiLiveServiceSessionFactory {
  const GeminiLiveServiceSessionFactory();

  GeminiLiveServiceSession build({
    required String wsUri,
    required String token,
    required String model,
    required String userNickname,
    required int silenceDurationMs,
    required String jlptLevel,
    required void Function(GeminiLiveState state) emitState,
    required void Function(String text) emitAiTextDelta,
    required void Function(TranscriptEntry entry) emitTranscriptEntry,
    required void Function(String message) emitError,
    String? characterName,
    String? voiceName,
    String? systemInstruction,
    String? scenarioGreeting,
    GeminiLiveAudioAdapter? audioAdapter,
    GeminiLiveMessageHandler? messageHandler,
    GeminiLivePromptBuilder? promptBuilder,
    GeminiLiveReconnectCoordinator? reconnectCoordinator,
    GeminiLiveLifecycleController? lifecycleController,
    GeminiLiveTransport? transport,
    GeminiLiveSessionComponentsFactory? sessionComponentsFactory,
    GeminiLiveSessionLifecycleRunnerFactory? lifecycleRunnerFactory,
  }) {
    final liveLifecycleController =
        lifecycleController ?? GeminiLiveLifecycleController();
    final liveAudioAdapter = audioAdapter ?? DefaultGeminiLiveAudioAdapter();
    final liveMessageHandler = messageHandler ?? GeminiLiveMessageHandler();
    final livePromptBuilder = promptBuilder ??
        GeminiLivePromptBuilder(
          jlptLevel: jlptLevel,
          systemInstruction: systemInstruction,
        );
    final liveReconnectCoordinator =
        reconnectCoordinator ?? GeminiLiveReconnectCoordinator();
    final liveTransport = transport ?? DefaultGeminiLiveTransport();
    final outboundSender = GeminiLiveOutboundSender(
      transport: liveTransport,
    );

    void emitStateIfActive(GeminiLiveState state) {
      if (liveLifecycleController.isDisposed) return;
      emitState(state);
    }

    final transcriptEmitter = GeminiLiveTranscriptEmitter(
      messageHandler: liveMessageHandler,
      emitEntry: emitTranscriptEntry,
    );
    final sessionComponents =
        (sessionComponentsFactory ?? const GeminiLiveSessionComponentsFactory())
            .build(
      model: model,
      userNickname: userNickname,
      silenceDurationMs: silenceDurationMs,
      audioAdapter: liveAudioAdapter,
      outboundSender: outboundSender,
      promptBuilder: livePromptBuilder,
      lifecycleController: liveLifecycleController,
      transport: liveTransport,
      emitError: emitError,
      emitAudioUnavailable: () => emitStateIfActive(GeminiLiveState.error),
      voiceName: voiceName,
      characterName: characterName,
      scenarioGreeting: scenarioGreeting,
    );
    final audioSession = sessionComponents.audioSession;
    final sessionRuntime = const GeminiLiveSessionRuntimeFactory().build(
      wsUri: wsUri,
      token: token,
      model: model,
      transport: liveTransport,
      reconnectCoordinator: liveReconnectCoordinator,
      setupSender: sessionComponents.setupSender,
      greetingSender: sessionComponents.greetingSender,
      audioSession: audioSession,
      messageHandler: liveMessageHandler,
      lifecycleController: liveLifecycleController,
      emitState: emitStateIfActive,
      emitError: emitError,
      onAiTextDelta: emitAiTextDelta,
      onTranscriptEntry: transcriptEmitter.emit,
      onAudioChunk: audioSession.playBase64Pcm,
    );
    final lifecycleRunner = (lifecycleRunnerFactory ??
            const GeminiLiveSessionLifecycleRunnerFactory())
        .build(
      lifecycleController: liveLifecycleController,
      reconnectCoordinator: liveReconnectCoordinator,
      connect: sessionRuntime.connect,
      stopRecording: audioSession.stopRecording,
      disposeAudio: audioSession.dispose,
      closeTransport: liveTransport.close,
      flushTranscripts: transcriptEmitter.flush,
      emitConnectingState: () => emitStateIfActive(GeminiLiveState.connecting),
      emitErrorState: () => emitStateIfActive(GeminiLiveState.error),
      emitEndingState: () => emitStateIfActive(GeminiLiveState.ending),
      emitEndedState: () => emitStateIfActive(GeminiLiveState.ended),
      emitError: emitError,
    );

    return GeminiLiveServiceSession(
      lifecycleController: liveLifecycleController,
      transcriptEmitter: transcriptEmitter,
      lifecycleRunner: lifecycleRunner,
    );
  }
}
