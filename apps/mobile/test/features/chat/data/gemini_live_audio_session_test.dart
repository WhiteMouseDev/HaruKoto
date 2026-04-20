import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_audio_adapter.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_audio_session.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_outbound_sender.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_transport.dart';

void main() {
  group('GeminiLiveAudioSession', () {
    test(
        'startRecording sends mic audio only while active connected and unmuted',
        () async {
      final audioAdapter = _FakeGeminiLiveAudioAdapter();
      final transport = _FakeGeminiLiveTransport();
      var active = true;
      var connected = true;
      var muted = false;
      final session = GeminiLiveAudioSession(
        audioAdapter: audioAdapter,
        outboundSender: GeminiLiveOutboundSender(transport: transport),
        isActive: () => active,
        isTransportConnected: () => connected,
        isMuted: () => muted,
        onError: (_) {},
        onUnavailable: () {},
      );

      await session.startRecording();
      audioAdapter.emitRecordedAudio(Uint8List.fromList([1, 2, 3]));
      muted = true;
      audioAdapter.emitRecordedAudio(Uint8List.fromList([4]));
      muted = false;
      connected = false;
      audioAdapter.emitRecordedAudio(Uint8List.fromList([5]));
      connected = true;
      active = false;
      audioAdapter.emitRecordedAudio(Uint8List.fromList([6]));

      expect(audioAdapter.startCalls, 1);
      expect(transport.sent, hasLength(1));

      final audio = jsonDecode(transport.sent.single) as Map<String, dynamic>;
      final realtimeInput = audio['realtimeInput'] as Map<String, dynamic>;
      final chunks = realtimeInput['mediaChunks'] as List<dynamic>;
      final chunk = chunks.first as Map<String, dynamic>;
      expect(chunk['mimeType'], 'audio/pcm;rate=16000');
      expect(chunk['data'], base64Encode([1, 2, 3]));
    });

    test('startRecording does not start the adapter while inactive', () async {
      final audioAdapter = _FakeGeminiLiveAudioAdapter();
      final session = GeminiLiveAudioSession(
        audioAdapter: audioAdapter,
        outboundSender: GeminiLiveOutboundSender(
          transport: _FakeGeminiLiveTransport(),
        ),
        isActive: () => false,
        isTransportConnected: () => true,
        isMuted: () => false,
        onError: (_) {},
        onUnavailable: () {},
      );

      await session.startRecording();

      expect(audioAdapter.startCalls, 0);
    });

    test('startRecording maps adapter failures to user-facing callbacks',
        () async {
      final errors = <String>[];
      var unavailableCalls = 0;
      final permissionDenied = _newSession(
        result: GeminiLiveAudioStartResult.permissionDenied,
        onError: errors.add,
        onUnavailable: () => unavailableCalls++,
      );
      final permissionCheckFailed = _newSession(
        result: GeminiLiveAudioStartResult.permissionCheckFailed,
        onError: errors.add,
        onUnavailable: () => unavailableCalls++,
      );
      final unavailable = _newSession(
        result: GeminiLiveAudioStartResult.unavailable,
        onError: errors.add,
        onUnavailable: () => unavailableCalls++,
      );

      await permissionDenied.startRecording();
      await permissionCheckFailed.startRecording();
      await unavailable.startRecording();

      expect(errors, [
        '마이크 권한이 필요합니다',
        '마이크를 사용할 수 없습니다. 기기를 확인해주세요.',
      ]);
      expect(unavailableCalls, 1);
    });

    test('stop dispose and playback delegate to the audio adapter', () async {
      final audioAdapter = _FakeGeminiLiveAudioAdapter();
      final session = GeminiLiveAudioSession(
        audioAdapter: audioAdapter,
        outboundSender: GeminiLiveOutboundSender(
          transport: _FakeGeminiLiveTransport(),
        ),
        isActive: () => true,
        isTransportConnected: () => true,
        isMuted: () => false,
        onError: (_) {},
        onUnavailable: () {},
      );

      session.playBase64Pcm('AAE=');
      await session.stopRecording();
      await session.dispose();

      expect(audioAdapter.playedAudio, ['AAE=']);
      expect(audioAdapter.stopCalls, 1);
      expect(audioAdapter.disposeCalls, 1);
    });
  });
}

GeminiLiveAudioSession _newSession({
  required GeminiLiveAudioStartResult result,
  required void Function(String message) onError,
  required void Function() onUnavailable,
}) {
  final audioAdapter = _FakeGeminiLiveAudioAdapter(result: result);
  return GeminiLiveAudioSession(
    audioAdapter: audioAdapter,
    outboundSender: GeminiLiveOutboundSender(
      transport: _FakeGeminiLiveTransport(),
    ),
    isActive: () => true,
    isTransportConnected: () => true,
    isMuted: () => false,
    onError: onError,
    onUnavailable: onUnavailable,
  );
}

class _FakeGeminiLiveAudioAdapter implements GeminiLiveAudioAdapter {
  _FakeGeminiLiveAudioAdapter({
    this.result = GeminiLiveAudioStartResult.started,
  });

  final GeminiLiveAudioStartResult result;
  int startCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;
  final playedAudio = <String>[];
  void Function(Uint8List data)? _onData;

  @override
  Future<GeminiLiveAudioStartResult> startRecording({
    required void Function(Uint8List data) onData,
  }) async {
    startCalls++;
    _onData = onData;
    return result;
  }

  void emitRecordedAudio(Uint8List data) {
    _onData?.call(data);
  }

  @override
  Future<void> stopRecording() async {
    stopCalls++;
  }

  @override
  void playBase64Pcm(String base64Data) {
    playedAudio.add(base64Data);
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
  }
}

class _FakeGeminiLiveTransport implements GeminiLiveTransport {
  final sent = <String>[];

  @override
  bool get isConnected => true;

  @override
  Future<void> connect(
    Uri uri, {
    required void Function(dynamic raw) onMessage,
    required void Function(Object error) onError,
    required void Function() onDone,
  }) async {}

  @override
  void send(String data) {
    sent.add(data);
  }

  @override
  Future<void> close() async {}
}
