import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Transcript entry for a single turn.
class TranscriptEntry {
  final String role; // 'user' or 'assistant'
  final String text;
  const TranscriptEntry({required this.role, required this.text});
  Map<String, String> toJson() => {'role': role, 'text': text};
}

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
  final int silenceDurationMs;
  final String jlptLevel;

  OnStateChange? onStateChange;
  OnAiTextDelta? onAiTextDelta;
  OnTranscriptEntry? onTranscriptEntry;
  OnError? onError;

  WebSocketChannel? _channel;
  int _channelGeneration = 0; // 채널 세대 추적 (이전 소켓 콜백 구분)
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _recorderSub;
  bool _disposed = false;
  bool _ended = false; // end()가 호출되었는지 추적
  bool _reconnecting = false; // 재연결 중복 방지
  bool isMuted = false;

  // Transcript accumulation
  final List<TranscriptEntry> _transcript = [];
  final StringBuffer _currentUserText = StringBuffer();
  final StringBuffer _currentAiText = StringBuffer();

  // Session resumption
  String? _resumptionHandle;
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 3;

  GeminiLiveService({
    required this.wsUri,
    required this.token,
    required this.model,
    this.characterName,
    this.voiceName,
    this.systemInstruction,
    this.scenarioGreeting,
    this.silenceDurationMs = 1200,
    this.jlptLevel = 'N5',
  });

  List<TranscriptEntry> get transcript {
    _flushTranscripts();
    return List.unmodifiable(_transcript);
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
    _reconnecting = false;
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
    unawaited(_channel?.sink.close());
    _channel = null;
    _setState(GeminiLiveState.ended);
  }

  /// Dispose all resources.
  Future<void> dispose() async {
    _disposed = true;
    _ended = true;
    await _stopRecording();
    unawaited(_channel?.sink.close());
    _channel = null;
    unawaited(_recorder.dispose());
    unawaited(FlutterPcmSound.release());
  }

  // ──────── Connection ────────

  Future<void> _connect({String? handle}) async {
    // URI를 안전하게 조합 (기존 query parameter 보존)
    final baseUri = Uri.parse(wsUri);
    final uri = baseUri.replace(queryParameters: {
      ...baseUri.queryParameters,
      'access_token': token,
    });

    _channelGeneration++;
    final gen = _channelGeneration;

    _channel = WebSocketChannel.connect(uri);
    await _channel!.ready;

    _channel!.stream.listen(
      _onMessage,
      onError: (e) {
        debugPrint('[GeminiLive] WebSocket error: $e');
        // 현재 세대의 채널에서만 재연결
        if (gen == _channelGeneration) _attemptReconnect();
      },
      onDone: () {
        debugPrint('[GeminiLive] WebSocket closed');
        // 현재 세대의 채널만 null 처리 (새 소켓이 있으면 건드리지 않음)
        if (gen == _channelGeneration) {
          _channel = null;
          if (!_disposed && !_ended) _attemptReconnect();
        }
      },
    );

    _sendSetup(handle: handle ?? _resumptionHandle);
  }

  void _sendSetup({String? handle}) {
    final instruction = systemInstruction ?? _defaultSystemInstruction();
    final setup = <String, dynamic>{
      'setup': {
        'model': model,
        'generationConfig': {
          'responseModalities': ['AUDIO'],
          'speechConfig': {
            'voiceConfig': {
              'prebuiltVoiceConfig': {
                'voiceName': voiceName ?? 'Kore',
              },
            },
          },
        },
        'systemInstruction': {
          'parts': [
            {'text': '$instruction\n\n${_jlptSection()}'},
          ],
        },
        'realtimeInputConfig': {
          'automaticActivityDetection': {
            'startOfSpeechSensitivity': 'START_SENSITIVITY_HIGH',
            'endOfSpeechSensitivity': 'END_SENSITIVITY_HIGH',
            'prefixPaddingMs': 300,
            'silenceDurationMs': silenceDurationMs,
          },
        },
        if (handle != null) 'sessionResumption': {'handle': handle},
      },
    };
    _safeSend(jsonEncode(setup));
  }

  // ──────── Message handling ────────

  void _onMessage(dynamic raw) {
    if (_disposed || _ended) return;

    // 메시지 파싱을 try-catch로 보호
    final Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[GeminiLive] Failed to parse message: $e');
      return;
    }

    // Setup complete → start mic + send greeting
    if (msg.containsKey('setupComplete')) {
      _reconnectAttempts = 0;
      _reconnecting = false; // 연결 완료 시점에 해제
      _setState(GeminiLiveState.connected);
      _sendGreeting();
      _startRecording();
      return;
    }

    // Session resumption handle
    if (msg.containsKey('sessionResumptionUpdate')) {
      final update = msg['sessionResumptionUpdate'] as Map<String, dynamic>?;
      _resumptionHandle = update?['newHandle'] as String?;
      return;
    }

    // GoAway → proactive reconnect
    if (msg.containsKey('goAway')) {
      _attemptReconnect();
      return;
    }

    // Server content (audio, transcriptions, turn management)
    final serverContent = msg['serverContent'] as Map<String, dynamic>?;
    if (serverContent == null) return;

    // Input transcription (user speech → text)
    final inputTranscription =
        serverContent['inputTranscription'] as Map<String, dynamic>?;
    if (inputTranscription != null) {
      final text = inputTranscription['text'] as String? ?? '';
      if (text.isNotEmpty) _currentUserText.write(text);
    }

    // Output transcription (AI speech → text)
    final outputTranscription =
        serverContent['outputTranscription'] as Map<String, dynamic>?;
    if (outputTranscription != null) {
      final text = outputTranscription['text'] as String? ?? '';
      if (text.isNotEmpty) {
        _currentAiText.write(text);
        onAiTextDelta?.call(text);
      }
    }

    // Audio data
    final modelTurn = serverContent['modelTurn'] as Map<String, dynamic>?;
    if (modelTurn != null) {
      // Flush user transcript when AI starts speaking
      _flushUserTranscript();

      final parts = modelTurn['parts'] as List<dynamic>? ?? [];
      for (final part in parts) {
        if (part is! Map<String, dynamic>) continue;
        final inlineData = part['inlineData'] as Map<String, dynamic>?;
        if (inlineData != null) {
          final b64 = inlineData['data'] as String?;
          if (b64 != null && b64.isNotEmpty) {
            _playAudioChunk(b64);
          }
        }
      }
    }

    // Turn complete
    if (serverContent['turnComplete'] == true) {
      _flushAiTranscript();
    }

    // Interrupted (barge-in)
    if (serverContent['interrupted'] == true) {
      _flushAiTranscript();
    }
  }

  // ──────── Greeting ────────

  void _sendGreeting() {
    final name = characterName ?? 'ハル';
    final greeting =
        scenarioGreeting ?? '[システム] $nameから電話がかかってきました。電話に出て「もしもし」から始めてください。';

    final msg = {
      'clientContent': {
        'turns': [
          {
            'role': 'user',
            'parts': [
              {'text': greeting},
            ],
          },
        ],
        'turnComplete': true,
      },
    };
    _safeSend(jsonEncode(msg));
  }

  // ──────── Recording ────────

  Future<void> _startRecording() async {
    if (_disposed || _ended) return;

    // 기존 녹음이 진행 중이면 먼저 정리
    await _stopRecording();

    if (!await _recorder.hasPermission()) {
      onError?.call('마이크 권한이 필요합니다');
      return;
    }

    // Initialize PCM player for output
    await FlutterPcmSound.setup(sampleRate: 24000, channelCount: 1);
    unawaited(FlutterPcmSound.setFeedThreshold(8000));

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      ),
    );

    _recorderSub = stream.listen((data) {
      if (_disposed || _channel == null || isMuted) return;
      final b64 = base64Encode(data);
      final msg = {
        'realtimeInput': {
          'mediaChunks': [
            {
              'mimeType': 'audio/pcm;rate=16000',
              'data': b64,
            },
          ],
        },
      };
      _safeSend(jsonEncode(msg));
    });
  }

  Future<void> _stopRecording() async {
    await _recorderSub?.cancel();
    _recorderSub = null;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }

  // ──────── Audio playback ────────

  void _playAudioChunk(String base64Data) {
    try {
      final bytes = base64Decode(base64Data);
      // Convert raw PCM bytes to Int16 samples for flutter_pcm_sound
      final byteData = ByteData.sublistView(Uint8List.fromList(bytes));
      final sampleCount = byteData.lengthInBytes ~/ 2;
      final samples = List<int>.generate(
        sampleCount,
        (i) => byteData.getInt16(i * 2, Endian.little),
      );
      final buffer = PcmArrayInt16.fromList(samples);
      FlutterPcmSound.feed(buffer);
    } catch (e) {
      debugPrint('[GeminiLive] Audio playback error: $e');
    }
  }

  // ──────── Transcripts ────────

  void _flushUserTranscript() {
    if (_currentUserText.isEmpty) return;
    final entry =
        TranscriptEntry(role: 'user', text: _currentUserText.toString().trim());
    if (entry.text.isNotEmpty) {
      _transcript.add(entry);
      onTranscriptEntry?.call(entry);
    }
    _currentUserText.clear();
  }

  void _flushAiTranscript() {
    if (_currentAiText.isEmpty) return;
    final entry = TranscriptEntry(
        role: 'assistant', text: _currentAiText.toString().trim());
    if (entry.text.isNotEmpty) {
      _transcript.add(entry);
      onTranscriptEntry?.call(entry);
    }
    _currentAiText.clear();
  }

  void _flushTranscripts() {
    _flushUserTranscript();
    _flushAiTranscript();
  }

  // ──────── Reconnection ────────

  void _attemptReconnect() {
    if (_disposed || _ended || _reconnecting) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      onError?.call('연결이 끊어졌습니다');
      _setState(GeminiLiveState.error);
      return;
    }

    _reconnecting = true;
    _reconnectAttempts++;
    final delay =
        Duration(milliseconds: 1000 * (1 << (_reconnectAttempts - 1)));
    debugPrint(
        '[GeminiLive] Reconnecting in ${delay.inMilliseconds}ms (attempt $_reconnectAttempts)');

    Future<void>.delayed(delay, () async {
      if (_disposed || _ended) {
        _reconnecting = false;
        return;
      }
      try {
        await _connect(handle: _resumptionHandle);
        // _reconnecting은 setupComplete 이벤트에서 해제됨
      } catch (e) {
        debugPrint('[GeminiLive] Reconnect failed: $e');
        _reconnecting = false;
        // 연결 실패 시 다음 재시도
        if (!_disposed && !_ended) _attemptReconnect();
      }
    });
  }

  // ──────── Safe send ────────

  /// WebSocket sink에 안전하게 전송 (sink 닫힌 상태 보호)
  void _safeSend(String data) {
    try {
      _channel?.sink.add(data);
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
