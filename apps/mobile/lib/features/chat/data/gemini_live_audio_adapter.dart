import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:record/record.dart';

typedef GeminiLiveAudioOutputSetup = Future<void> Function({
  required int sampleRate,
  required int channelCount,
});
typedef GeminiLiveAudioThresholdSetter = Future<void> Function(int threshold);
typedef GeminiLiveAudioOutputFeed = Future<void> Function(PcmArrayInt16 buffer);
typedef GeminiLiveAudioOutputRelease = Future<void> Function();

enum GeminiLiveAudioStartResult {
  started,
  permissionDenied,
  permissionCheckFailed,
  unavailable,
}

abstract class GeminiLiveAudioAdapter {
  Future<GeminiLiveAudioStartResult> startRecording({
    required void Function(Uint8List data) onData,
  });

  Future<void> stopRecording();

  void playBase64Pcm(String base64Data);

  Future<void> dispose();
}

class DefaultGeminiLiveAudioAdapter implements GeminiLiveAudioAdapter {
  DefaultGeminiLiveAudioAdapter({
    AudioRecorder? recorder,
    GeminiLiveAudioOutputSetup? setupOutput,
    GeminiLiveAudioThresholdSetter? setFeedThreshold,
    GeminiLiveAudioOutputFeed? feedOutput,
    GeminiLiveAudioOutputRelease? releaseOutput,
  })  : _recorder = recorder ?? AudioRecorder(),
        _setupOutput = setupOutput ??
            (({
              required int sampleRate,
              required int channelCount,
            }) =>
                FlutterPcmSound.setup(
                  sampleRate: sampleRate,
                  channelCount: channelCount,
                )),
        _setFeedThreshold =
            setFeedThreshold ?? FlutterPcmSound.setFeedThreshold,
        _feedOutput = feedOutput ?? FlutterPcmSound.feed,
        _releaseOutput = releaseOutput ?? FlutterPcmSound.release;

  final AudioRecorder _recorder;
  final GeminiLiveAudioOutputSetup _setupOutput;
  final GeminiLiveAudioThresholdSetter _setFeedThreshold;
  final GeminiLiveAudioOutputFeed _feedOutput;
  final GeminiLiveAudioOutputRelease _releaseOutput;
  StreamSubscription<Uint8List>? _recorderSub;

  @override
  Future<GeminiLiveAudioStartResult> startRecording({
    required void Function(Uint8List data) onData,
  }) async {
    await stopRecording();

    try {
      if (!await _recorder.hasPermission()) {
        return GeminiLiveAudioStartResult.permissionDenied;
      }
    } catch (e) {
      debugPrint('[GeminiLive] Microphone permission check failed: $e');
      return GeminiLiveAudioStartResult.permissionCheckFailed;
    }

    try {
      await _setupOutput(sampleRate: 24000, channelCount: 1);
      unawaited(_setFeedThreshold(8000));

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

      _recorderSub = stream.listen(onData);
      return GeminiLiveAudioStartResult.started;
    } catch (e) {
      debugPrint('[GeminiLive] Recording start failed: $e');
      return GeminiLiveAudioStartResult.unavailable;
    }
  }

  @override
  Future<void> stopRecording() async {
    await _recorderSub?.cancel();
    _recorderSub = null;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }

  @override
  void playBase64Pcm(String base64Data) {
    try {
      final bytes = base64Decode(base64Data);
      final byteData = ByteData.sublistView(Uint8List.fromList(bytes));
      final sampleCount = byteData.lengthInBytes ~/ 2;
      final samples = List<int>.generate(
        sampleCount,
        (i) => byteData.getInt16(i * 2, Endian.little),
      );
      final buffer = PcmArrayInt16.fromList(samples);
      unawaited(_feedOutput(buffer));
    } catch (e) {
      debugPrint('[GeminiLive] Audio playback error: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await stopRecording();
    await _recorder.dispose();
    await _releaseOutput();
  }
}
