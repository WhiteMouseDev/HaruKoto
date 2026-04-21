import 'gemini_live_connection_runner.dart';
import 'gemini_live_reconnect_coordinator.dart';
import 'gemini_live_setup_sender.dart';

class GeminiLiveSessionConnector {
  const GeminiLiveSessionConnector({
    required GeminiLiveConnectionRunner connectionRunner,
    required GeminiLiveReconnectCoordinator reconnectCoordinator,
    required GeminiLiveSetupSender setupSender,
  })  : _connectionRunner = connectionRunner,
        _reconnectCoordinator = reconnectCoordinator,
        _setupSender = setupSender;

  final GeminiLiveConnectionRunner _connectionRunner;
  final GeminiLiveReconnectCoordinator _reconnectCoordinator;
  final GeminiLiveSetupSender _setupSender;

  Future<void> connect(
    GeminiLiveConnectionInput input, {
    String? resumptionHandle,
  }) async {
    await _connectionRunner.connect(input);
    _setupSender.send(
      resumptionHandle:
          resumptionHandle ?? _reconnectCoordinator.resumptionHandle,
    );
  }
}
