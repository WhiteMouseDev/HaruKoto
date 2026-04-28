import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';

enum VoiceCallMicrophonePermissionResult {
  granted,
  denied,
  checkFailed,
}

typedef VoiceCallMicrophonePermissionRequester
    = Future<VoiceCallMicrophonePermissionResult> Function();

Future<VoiceCallMicrophonePermissionResult>
    allowVoiceCallMicrophonePermission() async {
  return VoiceCallMicrophonePermissionResult.granted;
}

final voiceCallMicrophonePermissionRequesterProvider =
    Provider<VoiceCallMicrophonePermissionRequester>((ref) {
  return requestVoiceCallMicrophonePermission;
});

Future<VoiceCallMicrophonePermissionResult>
    requestVoiceCallMicrophonePermission() async {
  final recorder = AudioRecorder();
  try {
    final granted = await recorder.hasPermission();
    return granted
        ? VoiceCallMicrophonePermissionResult.granted
        : VoiceCallMicrophonePermissionResult.denied;
  } catch (e) {
    debugPrint('[VoiceCallSession] Microphone permission check failed: $e');
    return VoiceCallMicrophonePermissionResult.checkFailed;
  } finally {
    try {
      await recorder.dispose();
    } catch (_) {}
  }
}
