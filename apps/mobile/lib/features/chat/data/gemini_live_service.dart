import 'dart:async';

import 'package:flutter/foundation.dart';

import 'gemini_live_audio_adapter.dart';
import 'gemini_live_message_handler.dart';
import 'gemini_live_protocol.dart';
import 'gemini_live_reconnect_coordinator.dart';
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
  final GeminiLiveReconnectCoordinator _reconnectCoordinator;
  final GeminiLiveTransport _transport;
  bool _disposed = false;
  bool _ended = false; // end()가 호출되었는지 추적
  bool isMuted = false;

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
    GeminiLiveReconnectCoordinator? reconnectCoordinator,
    GeminiLiveTransport? transport,
  })  : _audioAdapter = audioAdapter ?? DefaultGeminiLiveAudioAdapter(),
        _messageHandler = messageHandler ?? GeminiLiveMessageHandler(),
        _reconnectCoordinator =
            reconnectCoordinator ?? GeminiLiveReconnectCoordinator(),
        _transport = transport ?? DefaultGeminiLiveTransport();

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
    // 토큰에 / 가 포함되어 있으므로 인코딩하지 않고 그대로 사용
    final uri = Uri.parse('$wsUri?access_token=$token');
    debugPrint(
        '[GeminiLive] Connecting to: ${uri.scheme}://${uri.host}${uri.path}');
    debugPrint(
        '[GeminiLive] Token prefix: ${token.substring(0, token.length.clamp(0, 30))}...');
    debugPrint('[GeminiLive] Model: $model');

    final gen = _reconnectCoordinator.beginConnection();

    await _transport.connect(
      uri,
      onMessage: _onMessage,
      onError: (e) {
        debugPrint('[GeminiLive] WebSocket error: $e');
        // 현재 세대의 채널에서만 재연결
        if (_reconnectCoordinator.isCurrentConnection(gen)) {
          _attemptReconnect();
        }
      },
      onDone: () {
        debugPrint('[GeminiLive] WebSocket closed');
        // 현재 세대의 채널만 null 처리 (새 소켓이 있으면 건드리지 않음)
        if (_reconnectCoordinator.isCurrentConnection(gen)) {
          if (!_disposed && !_ended) _attemptReconnect();
        }
      },
    );

    _sendSetup(handle: handle ?? _reconnectCoordinator.resumptionHandle);
  }

  void _sendSetup({String? handle}) {
    final instruction = systemInstruction ?? _defaultSystemInstruction();
    _safeSend(
      GeminiLiveProtocol.encodeSetup(
        GeminiLiveSetupConfig(
          model: model,
          voiceName: voiceName,
          instruction: instruction,
          userNickname: userNickname,
          jlptSection: _jlptSection(),
          silenceDurationMs: silenceDurationMs,
          resumptionHandle: handle,
        ),
      ),
    );
  }

  // ──────── Message handling ────────

  void _onMessage(dynamic raw) {
    if (_disposed || _ended) return;

    // 메시지 파싱을 try-catch로 보호 (텍스트 + 바이너리 모두 처리)
    final Map<String, dynamic> msg;
    try {
      final parsed = GeminiLiveProtocol.parseMessage(raw);
      if (parsed == null) {
        debugPrint('[GeminiLive] Unknown message type: ${raw.runtimeType}');
        return;
      }
      msg = parsed;
    } catch (e) {
      debugPrint('[GeminiLive] Failed to parse message: $e');
      return;
    }

    for (final action in _messageHandler.handle(msg)) {
      _applyMessageAction(action);
    }
  }

  void _applyMessageAction(GeminiLiveMessageAction action) {
    switch (action.type) {
      case GeminiLiveMessageActionType.setupComplete:
        _reconnectCoordinator.markConnected();
        _setState(GeminiLiveState.connected);
        _sendGreeting();
        _startRecording();
      case GeminiLiveMessageActionType.updateResumptionHandle:
        _reconnectCoordinator.updateResumptionHandle(action.text);
      case GeminiLiveMessageActionType.reconnect:
        _attemptReconnect();
      case GeminiLiveMessageActionType.aiTextDelta:
        final text = action.text;
        if (text != null) onAiTextDelta?.call(text);
      case GeminiLiveMessageActionType.transcriptEntry:
        final entry = action.transcriptEntry;
        if (entry != null) onTranscriptEntry?.call(entry);
      case GeminiLiveMessageActionType.audioChunk:
        final base64Data = action.text;
        if (base64Data != null) _playAudioChunk(base64Data);
    }
  }

  // ──────── Greeting ────────

  void _sendGreeting() {
    _safeSend(
      GeminiLiveProtocol.encodeGreeting(
        characterName: characterName,
        scenarioGreeting: scenarioGreeting,
      ),
    );
  }

  // ──────── Recording ────────

  Future<void> _startRecording() async {
    if (_disposed || _ended) return;

    final result = await _audioAdapter.startRecording(
      onData: (data) {
        if (_disposed || !_transport.isConnected || isMuted) return;
        _safeSend(GeminiLiveProtocol.encodeRealtimeAudio(data));
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
    if (_disposed || _ended) return;

    final decision = _reconnectCoordinator.requestReconnect();
    switch (decision.status) {
      case GeminiLiveReconnectDecisionStatus.alreadyInProgress:
        return;
      case GeminiLiveReconnectDecisionStatus.exhausted:
        onError?.call('연결이 끊어졌습니다');
        _setState(GeminiLiveState.error);
        return;
      case GeminiLiveReconnectDecisionStatus.scheduled:
        break;
    }

    final delay = decision.delay!;
    final attempt = decision.attempt!;
    debugPrint(
        '[GeminiLive] Reconnecting in ${delay.inMilliseconds}ms (attempt $attempt)');

    Future<void>.delayed(delay, () async {
      if (_disposed || _ended) {
        _reconnectCoordinator.markReconnectIdle();
        return;
      }
      try {
        await _connect(handle: _reconnectCoordinator.resumptionHandle);
        // _reconnecting은 setupComplete 이벤트에서 해제됨
      } catch (e) {
        debugPrint('[GeminiLive] Reconnect failed: $e');
        _reconnectCoordinator.markReconnectIdle();
        // 연결 실패 시 다음 재시도
        if (!_disposed && !_ended) _attemptReconnect();
      }
    });
  }

  // ──────── Safe send ────────

  /// WebSocket sink에 안전하게 전송 (sink 닫힌 상태 보호)
  void _safeSend(String data) {
    try {
      _transport.send(data);
    } catch (e) {
      debugPrint('[GeminiLive] sink.add failed: $e');
    }
  }

  // ──────── State ────────

  void _setState(GeminiLiveState state) {
    if (_disposed) return;
    onStateChange?.call(state);
  }

  // ──────── System instructions ────────

  String _defaultSystemInstruction() {
    return '''あなたは日本に住んでいる日本人で、韓国人の友達と電話するのが好き。
明るくてフレンドリーな性格。

## ルール
- これは電話の会話です。実際の友達同士の電話のように自然に振る舞ってください。
- 最初の挨拶は「もしもし」「やっほー」など電話らしく。
- 会話中に文法を直接訂正しないでください。自然に正しい表現を使い返してください。
- 返答は1〜2文で簡潔に。電話の会話は短いやりとりが基本です。
- 相手のレベルに合わせて語彙の難易度を調整してください。''';
  }

  String _jlptSection() {
    switch (jlptLevel) {
      case 'N5':
        return '''## 日本語レベル: JLPT N5
- 基本的な挨拶と簡単な文のみ使用（語彙800語以内）
- です/ます形のみ使用
- 1文で返答''';
      case 'N4':
        return '''## 日本語レベル: JLPT N4
- 日常会話の基本（語彙1,500語以内）
- て形/ない形/可能形を使用可能
- 1〜2文で返答''';
      case 'N3':
        return '''## 日本語レベル: JLPT N3
- 日常会話が十分可能（語彙3,000語以内）
- 自然な口語体を使用
- 2〜3文で返答可能''';
      case 'N2':
        return '''## 日本語レベル: JLPT N2
- 複雑な会話が可能
- 慣用句やことわざも使用可能
- 自然な長さで返答''';
      case 'N1':
        return '''## 日本語レベル: JLPT N1
- ネイティブに近い理解力
- 語彙制限なし
- 自然な会話''';
      default:
        return '';
    }
  }
}
