class GeminiLiveLifecycleController {
  bool _disposed = false;
  bool _ended = false;
  bool isMuted = false;

  bool get isActive => !_disposed && !_ended;

  bool get isDisposed => _disposed;

  void markStarted() {
    _ended = false;
  }

  void markEnding() {
    _ended = true;
  }

  void markDisposed() {
    _disposed = true;
    _ended = true;
  }
}
