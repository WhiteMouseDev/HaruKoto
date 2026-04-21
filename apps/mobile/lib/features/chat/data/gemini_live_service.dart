import 'gemini_live_audio_adapter.dart';
import 'gemini_live_audio_session.dart';
import 'gemini_live_events.dart';
import 'gemini_live_greeting_sender.dart';
import 'gemini_live_lifecycle_controller.dart';
import 'gemini_live_message_handler.dart';
import 'gemini_live_outbound_sender.dart';
import 'gemini_live_prompt_builder.dart';
import 'gemini_live_reconnect_coordinator.dart';
import 'gemini_live_session_lifecycle_runner.dart';
import 'gemini_live_session_lifecycle_runner_factory.dart';
import 'gemini_live_session_runtime_factory.dart';
import 'gemini_live_setup_sender.dart';
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

  final GeminiLiveAudioAdapter _audioAdapter;
  final GeminiLiveMessageHandler _messageHandler;
  final GeminiLivePromptBuilder _promptBuilder;
  final GeminiLiveReconnectCoordinator _reconnectCoordinator;
  final GeminiLiveLifecycleController _lifecycleController;
  final GeminiLiveOutboundSender _outboundSender;
  late final GeminiLiveSetupSender _setupSender;
  late final GeminiLiveAudioSession _audioSession;
  late final GeminiLiveSessionRuntime _sessionRuntime;
  late final GeminiLiveSessionLifecycleRunner _sessionLifecycleRunner;

  GeminiLiveTransport get _transport => _outboundSender.transport;

  bool get isMuted => _lifecycleController.isMuted;

  set isMuted(bool value) {
    _lifecycleController.isMuted = value;
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
    GeminiLiveSessionLifecycleRunnerFactory? lifecycleRunnerFactory,
  })  : _audioAdapter = audioAdapter ?? DefaultGeminiLiveAudioAdapter(),
        _messageHandler = messageHandler ?? GeminiLiveMessageHandler(),
        _promptBuilder = promptBuilder ??
            GeminiLivePromptBuilder(
              jlptLevel: jlptLevel,
              systemInstruction: systemInstruction,
            ),
        _reconnectCoordinator =
            reconnectCoordinator ?? GeminiLiveReconnectCoordinator(),
        _lifecycleController =
            lifecycleController ?? GeminiLiveLifecycleController(),
        _outboundSender = GeminiLiveOutboundSender(
          transport: transport ?? DefaultGeminiLiveTransport(),
        ) {
    final greetingSender = GeminiLiveGreetingSender(
      outboundSender: _outboundSender,
      characterName: characterName,
      scenarioGreeting: scenarioGreeting,
    );
    _setupSender = GeminiLiveSetupSender(
      outboundSender: _outboundSender,
      promptBuilder: _promptBuilder,
      model: model,
      voiceName: voiceName,
      userNickname: userNickname,
      silenceDurationMs: silenceDurationMs,
    );
    _audioSession = GeminiLiveAudioSession(
      audioAdapter: _audioAdapter,
      outboundSender: _outboundSender,
      isActive: () => _lifecycleController.isActive,
      isTransportConnected: () => _transport.isConnected,
      isMuted: () => _lifecycleController.isMuted,
      onError: (message) => onError?.call(message),
      onUnavailable: () => _setState(GeminiLiveState.error),
    );
    _sessionRuntime = const GeminiLiveSessionRuntimeFactory().build(
      wsUri: wsUri,
      token: token,
      model: model,
      transport: _transport,
      reconnectCoordinator: _reconnectCoordinator,
      setupSender: _setupSender,
      greetingSender: greetingSender,
      audioSession: _audioSession,
      messageHandler: _messageHandler,
      lifecycleController: _lifecycleController,
      emitState: _setState,
      emitError: (message) => onError?.call(message),
      onAiTextDelta: _emitAiTextDelta,
      onTranscriptEntry: _emitTranscriptEntry,
      onAudioChunk: _playAudioChunk,
    );
    _sessionLifecycleRunner = (lifecycleRunnerFactory ??
            const GeminiLiveSessionLifecycleRunnerFactory())
        .build(
      lifecycleController: _lifecycleController,
      reconnectCoordinator: _reconnectCoordinator,
      connect: _sessionRuntime.connect,
      stopRecording: _audioSession.stopRecording,
      disposeAudio: _audioSession.dispose,
      closeTransport: _transport.close,
      flushTranscripts: _flushTranscripts,
      emitConnectingState: () => _setState(GeminiLiveState.connecting),
      emitErrorState: () => _setState(GeminiLiveState.error),
      emitEndingState: () => _setState(GeminiLiveState.ending),
      emitEndedState: () => _setState(GeminiLiveState.ended),
      emitError: (message) => onError?.call(message),
    );
  }

  List<TranscriptEntry> get transcript {
    _flushTranscripts();
    return _messageHandler.transcript;
  }

  /// Start the voice call: connect WebSocket, send setup, start mic.
  Future<void> start() {
    return _sessionLifecycleRunner.start(model: model);
  }

  /// End the voice call gracefully.
  Future<void> end() {
    return _sessionLifecycleRunner.end();
  }

  /// Dispose all resources.
  Future<void> dispose() {
    return _sessionLifecycleRunner.dispose();
  }

  void _emitAiTextDelta(String text) {
    onAiTextDelta?.call(text);
  }

  void _emitTranscriptEntry(TranscriptEntry entry) {
    onTranscriptEntry?.call(entry);
  }

  // ──────── Audio playback ────────

  void _playAudioChunk(String base64Data) {
    _audioSession.playBase64Pcm(base64Data);
  }

  // ──────── Transcripts ────────

  void _flushTranscripts() {
    for (final entry in _messageHandler.flushPendingTranscript()) {
      onTranscriptEntry?.call(entry);
    }
  }

  // ──────── State ────────

  void _setState(GeminiLiveState state) {
    if (_lifecycleController.isDisposed) return;
    onStateChange?.call(state);
  }
}
