import 'gemini_live_session_start_runner.dart';
import 'gemini_live_session_shutdown_runner.dart';

class GeminiLiveSessionLifecycleRunner {
  const GeminiLiveSessionLifecycleRunner({
    required GeminiLiveSessionStartRunner startRunner,
    required GeminiLiveSessionShutdownRunner shutdownRunner,
  })  : _startRunner = startRunner,
        _shutdownRunner = shutdownRunner;

  final GeminiLiveSessionStartRunner _startRunner;
  final GeminiLiveSessionShutdownRunner _shutdownRunner;

  Future<void> start({required String model}) => _startRunner.start(
        model: model,
      );

  Future<void> end() => _shutdownRunner.end();

  Future<void> dispose() => _shutdownRunner.dispose();
}
