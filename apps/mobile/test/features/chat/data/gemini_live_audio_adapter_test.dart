import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_audio_adapter.dart';
import 'package:record/record.dart';

void main() {
  group('DefaultGeminiLiveAudioAdapter', () {
    for (final dispose in [false, true]) {
      test(
          'a stream arriving after ${dispose ? 'dispose' : 'stop'} is cancelled',
          () async {
        final started = Completer<Stream<Uint8List>>();
        var streamCancelled = false;
        final lateStream = StreamController<Uint8List>(
          onCancel: () => streamCancelled = true,
        );
        final recorder = _FakeAudioRecorder()..startResult = started.future;
        final received = <Uint8List>[];
        final adapter = DefaultGeminiLiveAudioAdapter(
          recorder: recorder,
          isOutputSupported: () => false,
        );
        final starting = adapter.startRecording(onData: received.add);
        await Future<void>.delayed(Duration.zero);
        if (dispose) {
          await adapter.dispose();
        } else {
          await adapter.stopRecording();
        }
        started.complete(lateStream.stream);
        expect(await starting, GeminiLiveAudioStartResult.unavailable);
        expect(streamCancelled, isTrue);
        expect(received, isEmpty);
        expect(recorder.disposeCalls, dispose ? 2 : 0);
        expect(recorder.stopCalls, dispose ? 1 : 2);
        await lateStream.close();
        await adapter.dispose();
      });
    }

    test('a disposed pending permission request cannot reclaim PCM output',
        () async {
      final permission = Completer<bool>();
      final recorder = _FakeAudioRecorder()
        ..permissionResult = permission.future;
      var setupCalls = 0;
      final adapter = DefaultGeminiLiveAudioAdapter(
        recorder: recorder,
        setupOutput: (
                {required int sampleRate, required int channelCount}) async =>
            setupCalls++,
        setFeedThreshold: (_) async {},
        feedOutput: (_) async {},
        releaseOutput: () async {},
      );
      final starting = adapter.startRecording(onData: (_) {});
      await Future<void>.delayed(Duration.zero);
      await adapter.dispose();
      permission.complete(true);
      expect(await starting, GeminiLiveAudioStartResult.unavailable);
      expect(setupCalls, 0);
      expect(recorder.config, isNull);
    });

    for (final interruption in ['pause', 'stop', 'error', 'done']) {
      test(
          'reports native $interruption once without treating own stop as interruption',
          () async {
        final recorder = _FakeAudioRecorder();
        var interruptions = 0;
        final adapter = DefaultGeminiLiveAudioAdapter(
          recorder: recorder,
          isOutputSupported: () => false,
        )..onMicrophoneInterrupted = () => interruptions++;

        await adapter.startRecording(onData: (_) {});
        await Future<void>.delayed(Duration.zero);
        switch (interruption) {
          case 'pause':
            recorder.emitState(RecordState.pause);
          case 'stop':
            recorder.emitState(RecordState.stop);
          case 'error':
            recorder.failStream();
          case 'done':
            await recorder.finishStream();
        }
        await Future<void>.delayed(Duration.zero);
        expect(interruptions, 1);
        await adapter.stopRecording();
        await Future<void>.delayed(Duration.zero);
        expect(interruptions, 1);
        await adapter.dispose();
      });
    }

    test('stops a platform automatic resume after interruption', () async {
      final recorder = _FakeAudioRecorder();
      final adapter = DefaultGeminiLiveAudioAdapter(
        recorder: recorder,
        isOutputSupported: () => false,
      );
      await adapter.startRecording(onData: (_) {});
      await Future<void>.delayed(Duration.zero);
      recorder.emitState(RecordState.pause);
      await Future<void>.delayed(Duration.zero);
      recorder.emitState(RecordState.record);
      await Future<void>.delayed(Duration.zero);

      expect(recorder.stopCalls, 1);
      expect(recorder.recording, isFalse);
      await adapter.dispose();
    });

    test('startRecording starts recorder stream and forwards chunks', () async {
      final recorder = _FakeAudioRecorder();
      final forwarded = <Uint8List>[];
      int? capturedSampleRate;
      int? capturedChannelCount;
      int? feedThreshold;

      final adapter = DefaultGeminiLiveAudioAdapter(
        recorder: recorder,
        setupOutput: ({
          required int sampleRate,
          required int channelCount,
        }) async {
          capturedSampleRate = sampleRate;
          capturedChannelCount = channelCount;
        },
        setFeedThreshold: (threshold) async {
          feedThreshold = threshold;
        },
        feedOutput: (_) async {},
        releaseOutput: () async {},
      );

      final result = await adapter.startRecording(onData: forwarded.add);
      recorder.addChunk(Uint8List.fromList([1, 2, 3]));
      await Future<void>.delayed(Duration.zero);

      expect(result, GeminiLiveAudioStartResult.started);
      expect(capturedSampleRate, 24000);
      expect(capturedChannelCount, 1);
      expect(feedThreshold, 8000);
      expect(recorder.config?.encoder, AudioEncoder.pcm16bits);
      expect(recorder.config?.sampleRate, 16000);
      expect(recorder.config?.numChannels, 1);
      expect(forwarded.single, [1, 2, 3]);
    });

    test('preparePlayback allows model audio before recording starts',
        () async {
      var setupCalls = 0;
      PcmArrayInt16? fedBuffer;
      final adapter = DefaultGeminiLiveAudioAdapter(
        recorder: _FakeAudioRecorder(),
        setupOutput: ({
          required int sampleRate,
          required int channelCount,
        }) async {
          setupCalls++;
          expect(sampleRate, 24000);
          expect(channelCount, 1);
        },
        setFeedThreshold: (_) async {},
        feedOutput: (buffer) async {
          fedBuffer = buffer;
        },
        releaseOutput: () async {},
      );

      final result = await adapter.preparePlayback();
      adapter.playBase64Pcm(base64Encode([0x01, 0x00]));
      await Future<void>.delayed(Duration.zero);
      final startResult = await adapter.startRecording(onData: (_) {});

      expect(result, GeminiLiveAudioPlaybackPrepareResult.ready);
      expect(startResult, GeminiLiveAudioStartResult.started);
      expect(setupCalls, 1);
      expect(fedBuffer, isNotNull);
      expect(fedBuffer![0], 1);
    });

    test('startRecording returns permissionDenied before output setup',
        () async {
      final recorder = _FakeAudioRecorder()..permission = false;
      var setupCalled = false;
      final adapter = DefaultGeminiLiveAudioAdapter(
        recorder: recorder,
        setupOutput: ({
          required int sampleRate,
          required int channelCount,
        }) async {
          setupCalled = true;
        },
        setFeedThreshold: (_) async {},
        feedOutput: (_) async {},
        releaseOutput: () async {},
      );

      final result = await adapter.startRecording(onData: (_) {});

      expect(result, GeminiLiveAudioStartResult.permissionDenied);
      expect(setupCalled, isFalse);
      expect(recorder.config, isNull);
    });

    test('startRecording skips PCM output setup when output is unsupported',
        () async {
      final recorder = _FakeAudioRecorder();
      final forwarded = <Uint8List>[];
      var setupCalled = false;
      var thresholdCalled = false;
      final adapter = DefaultGeminiLiveAudioAdapter(
        recorder: recorder,
        setupOutput: ({
          required int sampleRate,
          required int channelCount,
        }) async {
          setupCalled = true;
        },
        setFeedThreshold: (_) async {
          thresholdCalled = true;
        },
        feedOutput: (_) async {
          fail('feedOutput should not be called when output is unsupported');
        },
        releaseOutput: () async {
          fail('releaseOutput should not be called when output is unsupported');
        },
        isOutputSupported: () => false,
      );

      final result = await adapter.startRecording(onData: forwarded.add);
      recorder.addChunk(Uint8List.fromList([4, 5, 6]));
      adapter.playBase64Pcm(base64Encode([0x01, 0x00]));
      await Future<void>.delayed(Duration.zero);
      await adapter.dispose();

      expect(result, GeminiLiveAudioStartResult.started);
      expect(setupCalled, isFalse);
      expect(thresholdCalled, isFalse);
      expect(recorder.config?.encoder, AudioEncoder.pcm16bits);
      expect(forwarded.single, [4, 5, 6]);
    });

    test('startRecording returns unavailable when output setup fails',
        () async {
      final recorder = _FakeAudioRecorder();
      final adapter = DefaultGeminiLiveAudioAdapter(
        recorder: recorder,
        setupOutput: ({
          required int sampleRate,
          required int channelCount,
        }) async {
          throw StateError('pcm setup failed');
        },
        setFeedThreshold: (_) async {},
        feedOutput: (_) async {},
        releaseOutput: () async {},
      );

      final result = await adapter.startRecording(onData: (_) {});

      expect(result, GeminiLiveAudioStartResult.unavailable);
      expect(recorder.config, isNull);
    });

    test('startRecording releases PCM output when threshold setup fails',
        () async {
      final recorder = _FakeAudioRecorder();
      var released = false;
      final adapter = DefaultGeminiLiveAudioAdapter(
        recorder: recorder,
        setupOutput: ({
          required int sampleRate,
          required int channelCount,
        }) async {},
        setFeedThreshold: (_) async {
          throw StateError('threshold failed');
        },
        feedOutput: (_) async {},
        releaseOutput: () async {
          released = true;
        },
      );

      final result = await adapter.startRecording(onData: (_) {});

      expect(result, GeminiLiveAudioStartResult.unavailable);
      expect(released, isTrue);
      expect(recorder.config, isNull);
    });

    test('playBase64Pcm decodes little endian PCM samples', () async {
      PcmArrayInt16? fedBuffer;
      final adapter = DefaultGeminiLiveAudioAdapter(
        recorder: _FakeAudioRecorder(),
        setupOutput: ({
          required int sampleRate,
          required int channelCount,
        }) async {},
        setFeedThreshold: (_) async {},
        feedOutput: (buffer) async {
          fedBuffer = buffer;
        },
        releaseOutput: () async {},
      );

      await adapter.startRecording(onData: (_) {});
      adapter.playBase64Pcm(base64Encode([0x01, 0x00, 0xff, 0x7f, 0x00, 0x80]));
      await Future<void>.delayed(Duration.zero);

      expect(fedBuffer, isNotNull);
      expect(fedBuffer!.count, 3);
      expect(fedBuffer![0], 1);
      expect(fedBuffer![1], 32767);
      expect(fedBuffer![2], -32768);
    });

    test('playBase64Pcm serializes feed calls in order', () async {
      final events = <String>[];
      final firstFeed = Completer<void>();
      var feedCalls = 0;
      final adapter = DefaultGeminiLiveAudioAdapter(
        recorder: _FakeAudioRecorder(),
        setupOutput: ({
          required int sampleRate,
          required int channelCount,
        }) async {},
        setFeedThreshold: (_) async {},
        feedOutput: (buffer) async {
          feedCalls++;
          events.add('start-$feedCalls:${buffer[0]}');
          if (feedCalls == 1) {
            await firstFeed.future;
          }
          events.add('end-$feedCalls:${buffer[0]}');
        },
        releaseOutput: () async {},
      );

      await adapter.startRecording(onData: (_) {});
      adapter.playBase64Pcm(base64Encode([0x01, 0x00]));
      adapter.playBase64Pcm(base64Encode([0x02, 0x00]));
      await Future<void>.delayed(Duration.zero);

      expect(events, ['start-1:1']);

      firstFeed.complete();
      await Future<void>.delayed(Duration.zero);
      await adapter.dispose();

      expect(events, ['start-1:1', 'end-1:1', 'start-2:2', 'end-2:2']);
    });

    test('dispose drops queued output after the active native feed completes',
        () async {
      final firstFeed = Completer<void>();
      final samples = <int>[];
      final adapter = DefaultGeminiLiveAudioAdapter(
        recorder: _FakeAudioRecorder(),
        setupOutput: (
            {required int sampleRate, required int channelCount}) async {},
        setFeedThreshold: (_) async {},
        feedOutput: (buffer) async {
          samples.add(buffer[0]);
          await firstFeed.future;
        },
        releaseOutput: () async {},
      );
      await adapter.preparePlayback();
      adapter.playBase64Pcm(base64Encode([1, 0]));
      adapter.playBase64Pcm(base64Encode([2, 0]));
      await Future<void>.delayed(Duration.zero);
      final disposing = adapter.dispose();
      firstFeed.complete();
      await disposing;
      expect(samples, [1]);
    });

    test('late old recorder cleanup cannot release a newer call output',
        () async {
      final stopped = Completer<void>();
      final recorder = _FakeAudioRecorder()..stopResult = stopped.future;
      final events = <String>[];
      final first = DefaultGeminiLiveAudioAdapter(
        recorder: recorder,
        setupOutput: (
                {required int sampleRate, required int channelCount}) async =>
            events.add('setup:first'),
        setFeedThreshold: (_) async {},
        feedOutput: (_) async {},
        releaseOutput: () async => events.add('release:first'),
      );
      await first.preparePlayback();
      recorder.recording = true;
      final oldCleanup = first.dispose();
      await Future<void>.delayed(Duration.zero);
      final second = DefaultGeminiLiveAudioAdapter(
        recorder: _FakeAudioRecorder(),
        setupOutput: (
                {required int sampleRate, required int channelCount}) async =>
            events.add('setup:second'),
        setFeedThreshold: (_) async {},
        feedOutput: (_) async => events.add('feed:second'),
        releaseOutput: () async => events.add('release:second'),
      );
      await second.preparePlayback();
      stopped.complete();
      await oldCleanup;
      second.playBase64Pcm(base64Encode([1, 0]));
      await Future<void>.delayed(Duration.zero);
      expect(events,
          ['setup:first', 'release:first', 'setup:second', 'feed:second']);
      await second.dispose();
      expect(events.last, 'release:second');
    });

    test('dispose stops recorder and releases output', () async {
      final recorder = _FakeAudioRecorder();
      var released = false;
      final adapter = DefaultGeminiLiveAudioAdapter(
        recorder: recorder,
        setupOutput: ({
          required int sampleRate,
          required int channelCount,
        }) async {},
        setFeedThreshold: (_) async {},
        feedOutput: (_) async {},
        releaseOutput: () async {
          released = true;
        },
      );

      await adapter.startRecording(onData: (_) {});
      await adapter.dispose();

      expect(recorder.stopCalls, 1);
      expect(recorder.disposed, isTrue);
      expect(released, isTrue);
    });
  });
}

class _FakeAudioRecorder extends AudioRecorder {
  final _controller = StreamController<Uint8List>.broadcast();
  final _stateController = StreamController<RecordState>.broadcast();

  bool permission = true;
  bool recording = false;
  Future<void>? stopResult;
  Future<bool>? permissionResult;
  Future<Stream<Uint8List>>? startResult;
  int disposeCalls = 0;
  bool disposed = false;
  int stopCalls = 0;
  RecordConfig? config;

  void addChunk(Uint8List data) {
    _controller.add(data);
  }

  void emitState(RecordState state) => _stateController.add(state);

  void failStream() => _controller.addError(StateError('audio interrupted'));

  Future<void> finishStream() => _controller.close();

  @override
  Stream<RecordState> onStateChanged() => _stateController.stream;

  @override
  Future<bool> hasPermission() async =>
      permissionResult == null ? permission : await permissionResult!;

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    this.config = config;
    recording = true;
    emitState(RecordState.record);
    return startResult == null ? _controller.stream : await startResult!;
  }

  @override
  Future<bool> isRecording() async => recording;

  @override
  Future<String?> stop() async {
    stopCalls++;
    await stopResult;
    recording = false;
    emitState(RecordState.stop);
    return null;
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    disposed = true;
    await _controller.close();
    await _stateController.close();
  }
}
