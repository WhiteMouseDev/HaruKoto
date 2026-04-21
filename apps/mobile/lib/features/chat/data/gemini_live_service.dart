import 'gemini_live_audio_adapter.dart';
import 'gemini_live_events.dart';
import 'gemini_live_lifecycle_controller.dart';
import 'gemini_live_message_handler.dart';
import 'gemini_live_prompt_builder.dart';
import 'gemini_live_reconnect_coordinator.dart';
import 'gemini_live_session_components_factory.dart';
import 'gemini_live_session_lifecycle_runner_factory.dart';
import 'gemini_live_service_session_factory.dart';
import 'gemini_live_transcript.dart';
import 'gemini_live_transport.dart';

export 'gemini_live_events.dart'
    show
        GeminiLiveState,
        OnAiTextDelta,
        OnError,
        OnStateChange,
        OnTranscriptEntry;
export 'gemini_live_transcript.dart' show TranscriptEntry;

/// Service that manages a Gemini Live voice call session.
class GeminiLiveService {
  final String wsUri;
  final String token;
  final String model;
  final String? characterName;
  final String? voiceName;
  final String? systemInstruction;
  final String? scenarioGreeting;
  final String userNickname;
  final int silenceDurationMs;
  final String jlptLevel;

  OnStateChange? onStateChange;
  OnAiTextDelta? onAiTextDelta;
  OnTranscriptEntry? onTranscriptEntry;
  OnError? onError;

  late final GeminiLiveServiceSession _session;

  bool get isMuted => _session.lifecycleController.isMuted;

  set isMuted(bool value) {
    _session.lifecycleController.isMuted = value;
  }

  GeminiLiveService({
    required this.wsUri,
    required this.token,
    required this.model,
    this.characterName,
    this.voiceName,
    this.systemInstruction,
    this.scenarioGreeting,
    this.userNickname = '학습자',
    this.silenceDurationMs = 1200,
    this.jlptLevel = 'N5',
    GeminiLiveAudioAdapter? audioAdapter,
    GeminiLiveMessageHandler? messageHandler,
    GeminiLivePromptBuilder? promptBuilder,
    GeminiLiveReconnectCoordinator? reconnectCoordinator,
    GeminiLiveLifecycleController? lifecycleController,
    GeminiLiveTransport? transport,
    GeminiLiveSessionComponentsFactory? sessionComponentsFactory,
    GeminiLiveSessionLifecycleRunnerFactory? lifecycleRunnerFactory,
  }) {
    _session = const GeminiLiveServiceSessionFactory().build(
      wsUri: wsUri,
      token: token,
      model: model,
      userNickname: userNickname,
      silenceDurationMs: silenceDurationMs,
      jlptLevel: jlptLevel,
      emitState: (state) => onStateChange?.call(state),
      emitAiTextDelta: (text) => onAiTextDelta?.call(text),
      emitTranscriptEntry: (entry) => onTranscriptEntry?.call(entry),
      emitError: (message) => onError?.call(message),
      characterName: characterName,
      voiceName: voiceName,
      systemInstruction: systemInstruction,
      scenarioGreeting: scenarioGreeting,
      audioAdapter: audioAdapter,
      messageHandler: messageHandler,
      promptBuilder: promptBuilder,
      reconnectCoordinator: reconnectCoordinator,
      lifecycleController: lifecycleController,
      transport: transport,
      sessionComponentsFactory: sessionComponentsFactory,
      lifecycleRunnerFactory: lifecycleRunnerFactory,
    );
  }

  List<TranscriptEntry> get transcript {
    return _session.transcriptEmitter.transcript;
  }

  /// Start the voice call: connect WebSocket, send setup, start mic.
  Future<void> start() {
    return _session.lifecycleRunner.start(model: model);
  }

  /// End the voice call gracefully.
  Future<void> end() {
    return _session.lifecycleRunner.end();
  }

  /// Dispose all resources.
  Future<void> dispose() {
    return _session.lifecycleRunner.dispose();
  }
}
