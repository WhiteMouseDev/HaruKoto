import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_audio_adapter.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_audio_session.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_outbound_sender.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_transport.dart';

void main() {
  group('GeminiLiveAudioSession', () {
    test('manual resume waits for an in-flight suspension stop', () async {
      final stopped = Completer<void>();
      final adapter = _FakeGeminiLiveAudioAdapter(stopResult: stopped.future);
      final session = GeminiLiveAudioSession(
        audioAdapter: adapter,
        outboundSender: GeminiLiveOutboundSender(
          transport: _FakeGeminiLiveTransport(),
        ),
        isActive: () => true,
        isTransportConnected: () => true,
        isMuted: () => false,
        onError: (_) {},
        onUnavailable: () {},
      );
      final suspending = session.suspendMicrophone();
      final resuming = session.resumeMicrophone();
      await Future<void>.delayed(Duration.zero);
      expect(adapter.startCalls, 0);
      stopped.complete();
      await suspending;
      expect(await resuming, isTrue);
      expect(adapter.startCalls, 1);
    });

    test('stops a microphone that finishes starting after the call ended',
        () async {
      final started = Completer<GeminiLiveAudioStartResult>();
      final adapter = _FakeGeminiLiveAudioAdapter(startResult: started.future);
      var active = true;
      final errors = <String>[];
      final session = GeminiLiveAudioSession(
        audioAdapter: adapter,
        outboundSender: GeminiLiveOutboundSender(
          transport: _FakeGeminiLiveTransport(),
        ),
        isActive: () => active,
        isTransportConnected: () => true,
        isMuted: () => false,
        onError: errors.add,
        onUnavailable: () => errors.add('unavailable'),
      );

      final starting = session.startRecording();
      await Future<void>.delayed(Duration.zero);
      active = false;
      await session.stopRecording();
      started.complete(GeminiLiveAudioStartResult.started);
      await starting;

      expect(adapter.stopCalls, 2);
      expect(errors, isEmpty);
    });

    test('interruption blocks automatic starts until an explicit resume',
        () async {
      final adapter = _FakeGeminiLiveAudioAdapter();
      final transport = _FakeGeminiLiveTransport();
      var interrupted = 0;
      var muted = true;
      var connected = true;
      final session = GeminiLiveAudioSession(
        audioAdapter: adapter,
        outboundSender: GeminiLiveOutboundSender(transport: transport),
        isActive: () => true,
        isTransportConnected: () => connected,
        isMuted: () => muted,
        onError: (_) {},
        onUnavailable: () {},
        onMicrophoneInterrupted: () => interrupted++,
      );

      await session.startRecording();
      adapter.onMicrophoneInterrupted?.call();
      await Future<void>.delayed(Duration.zero);
      await session.startRecording();
      adapter.emitRecordedAudio(Uint8List.fromList([1, 2]));
      expect(interrupted, 1);
      expect(adapter.startCalls, 1);
      expect(transport.sent, isEmpty);
      connected = false;
      expect(await session.resumeMicrophone(), isFalse);
      connected = true;
      expect(await session.resumeMicrophone(), isTrue);
      expect(adapter.startCalls, 2);
      adapter.emitRecordedAudio(Uint8List.fromList([3, 4]));
      expect(transport.sent, isEmpty); // The learner's mute choice survives.
      muted = false;
      adapter.emitRecordedAudio(Uint8List.fromList([5, 6]));
      expect(transport.sent, hasLength(1));
    });

    test('resume waits for and cleans a suspended pending start only once',
        () async {
      final started = Completer<GeminiLiveAudioStartResult>();
      final adapter = _FakeGeminiLiveAudioAdapter(startResult: started.future);
      final session = GeminiLiveAudioSession(
        audioAdapter: adapter,
        outboundSender: GeminiLiveOutboundSender(
          transport: _FakeGeminiLiveTransport(),
        ),
        isActive: () => true,
        isTransportConnected: () => true,
        isMuted: () => false,
        onError: (_) {},
        onUnavailable: () {},
      );

      final starting = session.startRecording();
      await Future<void>.delayed(Duration.zero);
      await session.suspendMicrophone();
      final resuming = session.resumeMicrophone();
      final duplicateResume = session.resumeMicrophone();
      await Future<void>.delayed(Duration.zero);
      expect(adapter.startCalls, 1);
      started.complete(GeminiLiveAudioStartResult.started);
      await starting;
      expect(await resuming, isTrue);
      expect(await duplicateResume, isTrue);
      expect(adapter.startCalls, 2);
      expect(adapter.stopCalls, 2);
    });

    testWidgets('a timed out mic resume stays suspended after late completion',
        (tester) async {
      final started = Completer<GeminiLiveAudioStartResult>();
      final adapter = _FakeGeminiLiveAudioAdapter(startResult: started.future);
      final transport = _FakeGeminiLiveTransport();
      final session = GeminiLiveAudioSession(
        audioAdapter: adapter,
        outboundSender: GeminiLiveOutboundSender(transport: transport),
        isActive: () => true,
        isTransportConnected: () => true,
        isMuted: () => false,
        onError: (_) {},
        onUnavailable: () {},
      );

      final resuming = session.resumeMicrophone();
      await tester.pump();
      await tester.pump(const Duration(seconds: 8));
      expect(await resuming, isFalse);
      started.complete(GeminiLiveAudioStartResult.started);
      await tester.pump();
      await session.startRecording();
      adapter.emitRecordedAudio(Uint8List.fromList([1, 2]));
      expect(adapter.startCalls, 1);
      expect(adapter.stopCalls, 2);
      expect(transport.sent, isEmpty);
    });

    test('late playback preparation cannot send a greeting after call end',
        () async {
      final prepared = Completer<GeminiLiveAudioPlaybackPrepareResult>();
      final adapter = _FakeGeminiLiveAudioAdapter(
        prepareResult: prepared.future,
      );
      var active = true;
      final session = GeminiLiveAudioSession(
        audioAdapter: adapter,
        outboundSender: GeminiLiveOutboundSender(
          transport: _FakeGeminiLiveTransport(),
        ),
        isActive: () => active,
        isTransportConnected: () => true,
        isMuted: () => false,
        onError: (_) {},
        onUnavailable: () {},
      );

      final preparing = session.preparePlayback();
      active = false;
      prepared.complete(GeminiLiveAudioPlaybackPrepareResult.ready);
      expect(await preparing, isFalse);
    });

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
      final chunk = realtimeInput['audio'] as Map<String, dynamic>;
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

      final prepared = await session.preparePlayback();
      session.playBase64Pcm('AAE=');
      await session.stopRecording();
      await session.dispose();

      expect(prepared, isTrue);
      expect(audioAdapter.prepareCalls, 1);
      expect(audioAdapter.playedAudio, ['AAE=']);
      expect(audioAdapter.stopCalls, 1);
      expect(audioAdapter.disposeCalls, 1);
    });

    test('preparePlayback maps output failures to user-facing callbacks',
        () async {
      final errors = <String>[];
      var unavailableCalls = 0;
      final session = _newSession(
        result: GeminiLiveAudioStartResult.started,
        playbackResult: GeminiLiveAudioPlaybackPrepareResult.unavailable,
        onError: errors.add,
        onUnavailable: () => unavailableCalls++,
      );

      final prepared = await session.preparePlayback();

      expect(prepared, isFalse);
      expect(errors, ['오디오를 재생할 수 없습니다. 기기를 확인해주세요.']);
      expect(unavailableCalls, 1);
    });
  });
}

GeminiLiveAudioSession _newSession({
  required GeminiLiveAudioStartResult result,
  GeminiLiveAudioPlaybackPrepareResult playbackResult =
      GeminiLiveAudioPlaybackPrepareResult.ready,
  required void Function(String message) onError,
  required void Function() onUnavailable,
}) {
  final audioAdapter = _FakeGeminiLiveAudioAdapter(
    result: result,
    playbackResult: playbackResult,
  );
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

class _FakeGeminiLiveAudioAdapter
    implements GeminiLiveAudioAdapter, GeminiLiveAudioInterruptionSource {
  _FakeGeminiLiveAudioAdapter({
    this.result = GeminiLiveAudioStartResult.started,
    this.playbackResult = GeminiLiveAudioPlaybackPrepareResult.ready,
    this.startResult,
    this.prepareResult,
    this.stopResult,
  });

  final GeminiLiveAudioStartResult result;
  final GeminiLiveAudioPlaybackPrepareResult playbackResult;
  final Future<GeminiLiveAudioStartResult>? startResult;
  final Future<GeminiLiveAudioPlaybackPrepareResult>? prepareResult;
  final Future<void>? stopResult;
  @override
  void Function()? onMicrophoneInterrupted;
  int prepareCalls = 0;
  int startCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;
  final playedAudio = <String>[];
  void Function(Uint8List data)? _onData;

  @override
  Future<GeminiLiveAudioPlaybackPrepareResult> preparePlayback() async {
    prepareCalls++;
    return await prepareResult ?? playbackResult;
  }

  @override
  Future<GeminiLiveAudioStartResult> startRecording({
    required void Function(Uint8List data) onData,
  }) async {
    startCalls++;
    _onData = onData;
    return await startResult ?? result;
  }

  void emitRecordedAudio(Uint8List data) {
    _onData?.call(data);
  }

  @override
  Future<void> stopRecording() async {
    stopCalls++;
    await stopResult;
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
