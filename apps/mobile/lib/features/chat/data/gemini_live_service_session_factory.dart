import 'gemini_live_audio_adapter.dart';
import 'gemini_live_events.dart';
import 'gemini_live_lifecycle_controller.dart';
import 'gemini_live_message_handler.dart';
import 'gemini_live_prompt_builder.dart';
import 'gemini_live_reconnect_coordinator.dart';
import 'gemini_live_session_components_factory.dart';
import 'gemini_live_session_dependencies.dart';
import 'gemini_live_session_event_sink.dart';
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
    final dependencies = const GeminiLiveSessionDependenciesFactory().build(
      jlptLevel: jlptLevel,
      systemInstruction: systemInstruction,
      audioAdapter: audioAdapter,
      messageHandler: messageHandler,
      promptBuilder: promptBuilder,
      reconnectCoordinator: reconnectCoordinator,
      lifecycleController: lifecycleController,
      transport: transport,
    );
    final eventSink = GeminiLiveSessionEventSink(
      lifecycleController: dependencies.lifecycleController,
      emitState: emitState,
      emitAiTextDelta: emitAiTextDelta,
      emitTranscriptEntry: emitTranscriptEntry,
      emitError: emitError,
    );

    final transcriptEmitter = GeminiLiveTranscriptEmitter(
      messageHandler: dependencies.messageHandler,
      emitEntry: eventSink.emitTranscriptEntry,
    );
    final sessionComponents =
        (sessionComponentsFactory ?? const GeminiLiveSessionComponentsFactory())
            .build(
      model: model,
      userNickname: userNickname,
      silenceDurationMs: silenceDurationMs,
      audioAdapter: dependencies.audioAdapter,
      outboundSender: dependencies.outboundSender,
      promptBuilder: dependencies.promptBuilder,
      lifecycleController: dependencies.lifecycleController,
      transport: dependencies.transport,
      emitError: eventSink.emitError,
      emitAudioUnavailable: eventSink.emitErrorState,
      voiceName: voiceName,
      characterName: characterName,
      scenarioGreeting: scenarioGreeting,
    );
    final audioSession = sessionComponents.audioSession;
    final sessionRuntime = const GeminiLiveSessionRuntimeFactory().build(
      wsUri: wsUri,
      token: token,
      model: model,
      transport: dependencies.transport,
      reconnectCoordinator: dependencies.reconnectCoordinator,
      setupSender: sessionComponents.setupSender,
      greetingSender: sessionComponents.greetingSender,
      audioSession: audioSession,
      messageHandler: dependencies.messageHandler,
      lifecycleController: dependencies.lifecycleController,
      emitState: eventSink.emitStateIfActive,
      emitError: eventSink.emitError,
      onAiTextDelta: eventSink.emitAiTextDelta,
      onTranscriptEntry: transcriptEmitter.emit,
      onAudioChunk: audioSession.playBase64Pcm,
    );
    final lifecycleRunner = (lifecycleRunnerFactory ??
            const GeminiLiveSessionLifecycleRunnerFactory())
        .build(
      lifecycleController: dependencies.lifecycleController,
      reconnectCoordinator: dependencies.reconnectCoordinator,
      connect: sessionRuntime.connect,
      stopRecording: audioSession.stopRecording,
      disposeAudio: audioSession.dispose,
      closeTransport: dependencies.transport.close,
      flushTranscripts: transcriptEmitter.flush,
      emitConnectingState: eventSink.emitConnectingState,
      emitErrorState: eventSink.emitErrorState,
      emitEndingState: eventSink.emitEndingState,
      emitEndedState: eventSink.emitEndedState,
      emitError: eventSink.emitError,
    );

    return GeminiLiveServiceSession(
      lifecycleController: dependencies.lifecycleController,
      transcriptEmitter: transcriptEmitter,
      lifecycleRunner: lifecycleRunner,
    );
  }
}
