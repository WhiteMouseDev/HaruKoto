import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundService {
  static const _keySoundEnabled = 'sound_enabled';

  static final SoundService _instance = SoundService._();
  factory SoundService() => _instance;
  SoundService._();

  final _player = AudioPlayer();
  bool _enabled = true;
  bool _initialized = false;

  bool get enabled => _enabled;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_keySoundEnabled) ?? true;
    _initialized = true;
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySoundEnabled, enabled);
  }

  Future<void> play(SoundType type) async {
    if (!_enabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/${type.filename}'));
    } catch (_) {
      // Silently ignore sound playback failures
    }
  }
}

enum SoundType {
  correct('correct.mp3'),
  wrong('wrong.mp3'),
  combo('combo.mp3'),
  complete('complete.mp3'),
  match('match.mp3');

  final String filename;
  const SoundType(this.filename);
}
