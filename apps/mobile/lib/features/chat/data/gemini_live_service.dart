import 'dart:async';

import 'package:flutter/foundation.dart';

import 'gemini_live_audio_adapter.dart';
import 'gemini_live_audio_session.dart';
import 'gemini_live_connection_runner.dart';
import 'gemini_live_inbound_dispatcher.dart';
import 'gemini_live_lifecycle_controller.dart';
import 'gemini_live_message_handler.dart';
import 'gemini_live_outbound_sender.dart';
import 'gemini_live_prompt_builder.dart';
import 'gemini_live_reconnect_coordinator.dart';
import 'gemini_live_reconnect_runner.dart';
import 'gemini_live_transcript.dart';
import 'gemini_live_transport.dart';

export 'gemini_live_transcript.dart' show TranscriptEntry;

/// Callbacks for voice call UI.
typedef OnStateChange = void Function(GeminiLiveState state);
typedef OnAiTextDelta = void Function(String text);
typedef OnTranscriptEntry = void Function(TranscriptEntry entry);
typedef OnError = void Function(String message);

enum GeminiLiveState { connecting, connected, ending, ended, error }

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
  late final GeminiLiveAudioSession _audioSession;
  late final GeminiLiveConnectionRunner _connectionRunner;
  late final GeminiLiveReconnectRunner _reconnectRunner;
  late final GeminiLiveInboundDispatcher _inboundDispatcher;

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
    _audioSession = GeminiLiveAudioSession(
      audioAdapter: _audioAdapter,
      outboundSender: _outboundSender,
      isActive: () => _lifecycleController.isActive,
      isTransportConnected: () => _transport.isConnected,
      isMuted: () => _lifecycleController.isMuted,
      onError: (message) => onError?.call(message),
      onUnavailable: () => _setState(GeminiLiveState.error),
    );
    _connectionRunner = GeminiLiveConnectionRunner(
      transport: _transport,
      reconnectCoordinator: _reconnectCoordinator,
      isActive: () => _lifecycleController.isActive,
      onMessage: _onMessage,
      onReconnect: _attemptReconnect,
    );
    _reconnectRunner = GeminiLiveReconnectRunner(
      coordinator: _reconnectCoordinator,
      isActive: () => _lifecycleController.isActive,
      onConnect: (handle) => _connect(handle: handle),
      onExhausted: () {
        onError?.call('연결이 끊어졌습니다');
        _setState(GeminiLiveState.error);
      },
    );
    _inboundDispatcher = GeminiLiveInboundDispatcher(
      messageHandler: _messageHandler,
      isActive: () => _lifecycleController.isActive,
      onSetupComplete: _handleSetupComplete,
      onUpdateResumptionHandle: _reconnectCoordinator.updateResumptionHandle,
      onReconnect: _attemptReconnect,
      onAiTextDelta: _emitAiTextDelta,
      onTranscriptEntry: _emitTranscriptEntry,
      onAudioChunk: _playAudioChunk,
    );
  }

  List<TranscriptEntry> get transcript {
    _flushTranscripts();
    return _messageHandler.transcript;
  }

  /// Start the voice call: connect WebSocket, send setup, start mic.
  Future<void> start() async {
    // model 유효성 검증
    if (model.isEmpty) {
      onError?.call('음성 모델이 설정되지 않았습니다');
      _setState(GeminiLiveState.error);
      return;
    }

    _lifecycleController.markStarted();
    _reconnectCoordinator.resetForStart();
    _setState(GeminiLiveState.connecting);
    try {
      await _connect();
    } catch (e) {
      debugPrint('[GeminiLive] Start failed: $e');
      onError?.call('연결에 실패했습니다');
      _setState(GeminiLiveState.error);
    }
  }

  /// End the voice call gracefully.
  Future<void> end() async {
    _lifecycleController.markEnding();
    _setState(GeminiLiveState.ending);
    _flushTranscripts();
    await _audioSession.stopRecording();
    unawaited(_transport.close());
    _setState(GeminiLiveState.ended);
  }

  /// Dispose all resources.
  Future<void> dispose() async {
    _lifecycleController.markDisposed();
    await _audioSession.dispose();
    unawaited(_transport.close());
  }

  // ──────── Connection ────────

  Future<void> _connect({String? handle}) async {
    await _connectionRunner.connect(
      GeminiLiveConnectionInput(
        wsUri: wsUri,
        token: token,
        model: model,
      ),
    );

    _sendSetup(handle: handle ?? _reconnectCoordinator.resumptionHandle);
  }

  void _sendSetup({String? handle}) {
    _outboundSender.sendSetup(
      model: model,
      voiceName: voiceName,
      instruction: _promptBuilder.instruction,
      userNickname: userNickname,
      jlptSection: _promptBuilder.jlptSection,
      silenceDurationMs: silenceDurationMs,
      resumptionHandle: handle,
    );
  }

  // ──────── Message handling ────────

  void _onMessage(dynamic raw) {
    _inboundDispatcher.dispatch(raw);
  }

  void _handleSetupComplete() {
    _reconnectCoordinator.markConnected();
    _setState(GeminiLiveState.connected);
    _sendGreeting();
    _audioSession.startRecording();
  }

  void _emitAiTextDelta(String text) {
    onAiTextDelta?.call(text);
  }

  void _emitTranscriptEntry(TranscriptEntry entry) {
    onTranscriptEntry?.call(entry);
  }

  // ──────── Greeting ────────

  void _sendGreeting() {
    _outboundSender.sendGreeting(
      characterName: characterName,
      scenarioGreeting: scenarioGreeting,
    );
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

  // ──────── Reconnection ────────

  void _attemptReconnect() {
    _reconnectRunner.attemptReconnect();
  }

  // ──────── State ────────

  void _setState(GeminiLiveState state) {
    if (_lifecycleController.isDisposed) return;
    onStateChange?.call(state);
  }
}
