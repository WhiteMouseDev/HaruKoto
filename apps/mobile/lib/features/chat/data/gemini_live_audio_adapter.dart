import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:record/record.dart';

import 'gemini_live_audio_output_gate.dart';

import 'gemini_live_audio_environment.dart';

typedef GeminiLiveAudioOutputSetup = Future<void> Function({
  required int sampleRate,
  required int channelCount,
});
typedef GeminiLiveAudioThresholdSetter = Future<void> Function(int threshold);
typedef GeminiLiveAudioOutputFeed = Future<void> Function(PcmArrayInt16 buffer);
typedef GeminiLiveAudioOutputRelease = Future<void> Function();
typedef GeminiLiveAudioOutputSupportChecker = bool Function();

enum GeminiLiveAudioStartResult {
  started,
  permissionDenied,
  permissionCheckFailed,
  unavailable,
}

enum GeminiLiveAudioPlaybackPrepareResult {
  ready,
  unsupported,
  unavailable,
}

abstract class GeminiLiveAudioAdapter {
  Future<GeminiLiveAudioPlaybackPrepareResult> preparePlayback();

  Future<GeminiLiveAudioStartResult> startRecording({
    required void Function(Uint8List data) onData,
  });

  Future<void> stopRecording();

  void playBase64Pcm(String base64Data);

  Future<void> dispose();
}

abstract interface class GeminiLiveAudioInterruptionSource {
  set onMicrophoneInterrupted(void Function()? callback);
}

class DefaultGeminiLiveAudioAdapter
    implements GeminiLiveAudioAdapter, GeminiLiveAudioInterruptionSource {
  static final _outputGate = GeminiLiveAudioOutputGate();
  DefaultGeminiLiveAudioAdapter({
    AudioRecorder? recorder,
    GeminiLiveAudioOutputSetup? setupOutput,
    GeminiLiveAudioThresholdSetter? setFeedThreshold,
    GeminiLiveAudioOutputFeed? feedOutput,
    GeminiLiveAudioOutputRelease? releaseOutput,
    GeminiLiveAudioOutputSupportChecker? isOutputSupported,
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
        _releaseOutput = releaseOutput ?? FlutterPcmSound.release,
        _isOutputSupported =
            isOutputSupported ?? isGeminiLivePcmOutputSupported;

  final AudioRecorder _recorder;
  final GeminiLiveAudioOutputSetup _setupOutput;
  final GeminiLiveAudioThresholdSetter _setFeedThreshold;
  final GeminiLiveAudioOutputFeed _feedOutput;
  final GeminiLiveAudioOutputRelease _releaseOutput;
  final GeminiLiveAudioOutputSupportChecker _isOutputSupported;
  StreamSubscription<Uint8List>? _recorderSub;
  StreamSubscription<RecordState>? _recorderStateSub;
  bool _recordingExpected = false;
  bool _observedRecording = false;
  @override
  void Function()? onMicrophoneInterrupted;
  Future<void> _playbackQueue = Future<void>.value();
  bool _outputReady = false;
  bool _disposed = false;
  Future<void>? _disposal;

  @override
  Future<GeminiLiveAudioPlaybackPrepareResult> preparePlayback() async {
    if (_disposed) return GeminiLiveAudioPlaybackPrepareResult.unavailable;
    if (_outputReady && _outputGate.owns(this)) {
      return GeminiLiveAudioPlaybackPrepareResult.ready;
    }

    try {
      if (!_isOutputSupported()) {
        debugPrint(
          '[GeminiLive] PCM output disabled for this runtime environment',
        );
        return GeminiLiveAudioPlaybackPrepareResult.unsupported;
      }

      await _outputGate.prepare(
        this,
        setup: () async {
          await _setupOutput(sampleRate: 24000, channelCount: 1);
          await _setFeedThreshold(8000);
        },
        release: _releaseOutput,
      );
      if (_disposed) {
        await _releaseReadyOutput();
        return GeminiLiveAudioPlaybackPrepareResult.unavailable;
      }
      _outputReady = true;
      return GeminiLiveAudioPlaybackPrepareResult.ready;
    } catch (e) {
      _outputReady = false;
      debugPrint('[GeminiLive] Playback setup failed: $e');
      return GeminiLiveAudioPlaybackPrepareResult.unavailable;
    }
  }

  @override
  Future<GeminiLiveAudioStartResult> startRecording({
    required void Function(Uint8List data) onData,
  }) async {
    if (_disposed) return GeminiLiveAudioStartResult.unavailable;
    await stopRecording();
    if (_disposed) return GeminiLiveAudioStartResult.unavailable;

    try {
      if (!await _recorder.hasPermission()) {
        return GeminiLiveAudioStartResult.permissionDenied;
      }
    } catch (e) {
      debugPrint('[GeminiLive] Microphone permission check failed: $e');
      return GeminiLiveAudioStartResult.permissionCheckFailed;
    }
    if (_disposed) return GeminiLiveAudioStartResult.unavailable;

    final playbackResult = await preparePlayback();
    if (_disposed ||
        playbackResult == GeminiLiveAudioPlaybackPrepareResult.unavailable) {
      return GeminiLiveAudioStartResult.unavailable;
    }

    try {
      _recorderStateSub ??= _recorder.onStateChanged().listen(
        (state) {
          if (state == RecordState.pause || state == RecordState.stop) {
            if (_observedRecording) _notifyMicrophoneInterrupted();
          } else if (state == RecordState.record && _recordingExpected) {
            _observedRecording = true;
          } else if (state == RecordState.record) {
            // Some platforms resume after an interruption automatically.
            // Keep the explicit suspension until the learner resumes.
            unawaited(stopRecording().catchError((Object error) {
              debugPrint('[GeminiLive] Unexpected recorder resume: $error');
            }));
          }
        },
        onError: (Object _) => _notifyMicrophoneInterrupted(),
      );
      _recordingExpected = true;
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

      if (_disposed || !_recordingExpected) {
        // record can finish creating its Dart stream after native stop/dispose
        // completed. Do not attach the live callback to that late stream.
        await stream.listen((_) {}).cancel();
        if (_disposed) {
          await _recorder.dispose();
        } else {
          await _recorder.stop();
        }
        return GeminiLiveAudioStartResult.unavailable;
      }

      _recorderSub = stream.listen(
        onData,
        onError: (Object _) => _notifyMicrophoneInterrupted(),
        onDone: _notifyMicrophoneInterrupted,
      );
      return GeminiLiveAudioStartResult.started;
    } catch (e) {
      _recordingExpected = false;
      await _releaseReadyOutput();
      debugPrint('[GeminiLive] Recording start failed: $e');
      return GeminiLiveAudioStartResult.unavailable;
    }
  }

  @override
  Future<void> stopRecording() async {
    _recordingExpected = false;
    _observedRecording = false;
    await _recorderSub?.cancel();
    _recorderSub = null;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }

  @override
  void playBase64Pcm(String base64Data) {
    if (_disposed || !_outputReady || !_outputGate.owns(this)) return;

    try {
      final bytes = base64Decode(base64Data);
      final byteData = ByteData.sublistView(Uint8List.fromList(bytes));
      final sampleCount = byteData.lengthInBytes ~/ 2;
      final samples = List<int>.generate(
        sampleCount,
        (i) => byteData.getInt16(i * 2, Endian.little),
      );
      final buffer = PcmArrayInt16.fromList(samples);
      _playbackQueue = _playbackQueue.catchError((_) {}).then((_) async {
        if (_disposed || !_outputReady) return;
        await _outputGate.feed(this, () => _feedOutput(buffer));
      }).catchError((Object e) {
        _outputReady = false;
        debugPrint('[GeminiLive] Audio playback error: $e');
      });
    } catch (e) {
      debugPrint('[GeminiLive] Audio playback error: $e');
    }
  }

  @override
  Future<void> dispose() {
    _disposed = true;
    return _disposal ??= _dispose();
  }

  Future<void> _dispose() async {
    try {
      await stopRecording();
    } finally {
      try {
        await _recorderStateSub?.cancel();
        _recorderStateSub = null;
        await _recorder.dispose();
      } finally {
        await _playbackQueue.catchError((_) {});
        await _releaseReadyOutput();
      }
    }
  }

  void _notifyMicrophoneInterrupted() {
    if (!_recordingExpected) return;
    _recordingExpected = false;
    _observedRecording = false;
    onMicrophoneInterrupted?.call();
  }

  Future<void> _releaseReadyOutput() async {
    if (_outputGate.owns(this)) {
      try {
        await _outputGate.release(this);
      } catch (e) {
        debugPrint('[GeminiLive] Audio output release failed: $e');
      } finally {
        _outputReady = false;
      }
    }
  }
}
