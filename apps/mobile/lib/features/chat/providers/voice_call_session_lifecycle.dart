import 'voice_call_connection_service.dart';

class VoiceCallSessionLifecycle {
  VoiceCallSessionRequest? _request;
  bool _disposed = false;
  int _generation = 0;

  VoiceCallSessionRequest? get request => _request;

  bool get isDisposed => _disposed;

  int begin(VoiceCallSessionRequest request) {
    _request = request;
    _generation++;
    return _generation;
  }

  void markDisposed() {
    _disposed = true;
    _generation++;
  }

  bool isStale(int generation) {
    return _disposed || generation != _generation;
  }
}
