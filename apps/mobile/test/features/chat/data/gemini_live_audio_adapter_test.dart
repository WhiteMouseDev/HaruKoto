import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_audio_adapter.dart';
import 'package:record/record.dart';

void main() {
  group('DefaultGeminiLiveAudioAdapter', () {
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
      await adapter.dispose();

      expect(events, ['start-1:1', 'end-1:1', 'start-2:2', 'end-2:2']);
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

  bool permission = true;
  bool recording = false;
  bool disposed = false;
  int stopCalls = 0;
  RecordConfig? config;

  void addChunk(Uint8List data) {
    _controller.add(data);
  }

  @override
  Future<bool> hasPermission() async => permission;

  @override
  Future<Stream<Uint8List>> startStream(RecordConfig config) async {
    this.config = config;
    recording = true;
    return _controller.stream;
  }

  @override
  Future<bool> isRecording() async => recording;

  @override
  Future<String?> stop() async {
    stopCalls++;
    recording = false;
    return null;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _controller.close();
  }
}
