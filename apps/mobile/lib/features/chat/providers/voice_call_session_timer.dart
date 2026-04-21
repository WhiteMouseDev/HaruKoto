import 'dart:async';

abstract class VoiceCallSessionTimer {
  void start(void Function() onTick);
  void stop();
  void dispose();
}

class PeriodicVoiceCallSessionTimer implements VoiceCallSessionTimer {
  Timer? _timer;
  bool _disposed = false;

  @override
  void start(void Function() onTick) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      onTick();
    });
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
  }
}
