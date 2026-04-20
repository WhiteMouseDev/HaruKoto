import 'dart:async';

import 'package:flutter/foundation.dart';

import 'gemini_live_audio_adapter.dart';
import 'gemini_live_connection_runner.dart';
import 'gemini_live_inbound_dispatcher.dart';
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
  final GeminiLiveOutboundSender _outboundSender;
  late final GeminiLiveConnectionRunner _connectionRunner;
  late final GeminiLiveReconnectRunner _reconnectRunner;
  late final GeminiLiveInboundDispatcher _inboundDispatcher;
  bool _disposed = false;
  bool _ended = false; // end()가 호출되었는지 추적
  bool isMuted = false;

  GeminiLiveTransport get _transport => _outboundSender.transport;

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
        _outboundSender = GeminiLiveOutboundSender(
          transport: transport ?? DefaultGeminiLiveTransport(),
        ) {
    _connectionRunner = GeminiLiveConnectionRunner(
      transport: _transport,
      reconnectCoordinator: _reconnectCoordinator,
      isActive: () => !_disposed && !_ended,
      onMessage: _onMessage,
      onReconnect: _attemptReconnect,
    );
    _reconnectRunner = GeminiLiveReconnectRunner(
      coordinator: _reconnectCoordinator,
      isActive: () => !_disposed && !_ended,
      onConnect: (handle) => _connect(handle: handle),
      onExhausted: () {
        onError?.call('연결이 끊어졌습니다');
        _setState(GeminiLiveState.error);
      },
    );
    _inboundDispatcher = GeminiLiveInboundDispatcher(
      messageHandler: _messageHandler,
      isActive: () => !_disposed && !_ended,
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

    _ended = false;
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
    _ended = true; // 재연결 방지 플래그
    _setState(GeminiLiveState.ending);
    _flushTranscripts();
    await _stopRecording();
    unawaited(_transport.close());
    _setState(GeminiLiveState.ended);
  }

  /// Dispose all resources.
  Future<void> dispose() async {
    _disposed = true;
    _ended = true;
    await _audioAdapter.dispose();
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
    _startRecording();
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

  // ──────── Recording ────────

  Future<void> _startRecording() async {
    if (_disposed || _ended) return;

    final result = await _audioAdapter.startRecording(
      onData: (data) {
        if (_disposed || !_transport.isConnected || isMuted) return;
        _outboundSender.sendRealtimeAudio(data);
      },
    );

    switch (result) {
      case GeminiLiveAudioStartResult.started:
        return;
      case GeminiLiveAudioStartResult.permissionDenied:
        onError?.call('마이크 권한이 필요합니다');
        return;
      case GeminiLiveAudioStartResult.permissionCheckFailed:
        // 시뮬레이터 등에서 마이크 접근 불가 시 녹음 없이 계속
        return;
      case GeminiLiveAudioStartResult.unavailable:
        onError?.call('마이크를 사용할 수 없습니다. 기기를 확인해주세요.');
        _setState(GeminiLiveState.error);
    }
  }

  Future<void> _stopRecording() async {
    await _audioAdapter.stopRecording();
  }

  // ──────── Audio playback ────────

  void _playAudioChunk(String base64Data) {
    _audioAdapter.playBase64Pcm(base64Data);
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
    if (_disposed) return;
    onStateChange?.call(state);
  }
}
