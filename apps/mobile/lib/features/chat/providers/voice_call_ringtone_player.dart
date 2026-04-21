import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class VoiceCallRingtonePlayer {
  Future<void> startLoop();
  Future<void> stop();
  Future<void> dispose();
}

class AudioVoiceCallRingtonePlayer implements VoiceCallRingtonePlayer {
  AudioVoiceCallRingtonePlayer() : _player = AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> startLoop() async {
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(0.5);
    await _player.play(AssetSource('sounds/ringtone.wav'));
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() => _player.dispose();
}

typedef VoiceCallRingtonePlayerFactory = VoiceCallRingtonePlayer Function();

final voiceCallRingtonePlayerFactoryProvider =
    Provider<VoiceCallRingtonePlayerFactory>(
  (ref) => AudioVoiceCallRingtonePlayer.new,
);
