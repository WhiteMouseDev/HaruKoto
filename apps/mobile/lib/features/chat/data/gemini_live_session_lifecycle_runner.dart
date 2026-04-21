import 'package:flutter/foundation.dart';

import 'gemini_live_lifecycle_actions.dart';
import 'gemini_live_lifecycle_controller.dart';
import 'gemini_live_reconnect_coordinator.dart';
import 'gemini_live_session_shutdown_runner.dart';

class GeminiLiveSessionLifecycleRunner {
  const GeminiLiveSessionLifecycleRunner({
    required GeminiLiveLifecycleController lifecycleController,
    required GeminiLiveReconnectCoordinator reconnectCoordinator,
    required GeminiLiveLifecycleAsyncAction connect,
    required GeminiLiveSessionShutdownRunner shutdownRunner,
    required GeminiLiveLifecycleSyncAction emitConnectingState,
    required GeminiLiveLifecycleSyncAction emitErrorState,
    required GeminiLiveLifecycleErrorEmitter emitError,
  })  : _lifecycleController = lifecycleController,
        _reconnectCoordinator = reconnectCoordinator,
        _connect = connect,
        _shutdownRunner = shutdownRunner,
        _emitConnectingState = emitConnectingState,
        _emitErrorState = emitErrorState,
        _emitError = emitError;

  final GeminiLiveLifecycleController _lifecycleController;
  final GeminiLiveReconnectCoordinator _reconnectCoordinator;
  final GeminiLiveLifecycleAsyncAction _connect;
  final GeminiLiveSessionShutdownRunner _shutdownRunner;
  final GeminiLiveLifecycleSyncAction _emitConnectingState;
  final GeminiLiveLifecycleSyncAction _emitErrorState;
  final GeminiLiveLifecycleErrorEmitter _emitError;

  Future<void> start({required String model}) async {
    if (model.isEmpty) {
      _emitError('음성 모델이 설정되지 않았습니다');
      _emitErrorState();
      return;
    }

    _lifecycleController.markStarted();
    _reconnectCoordinator.resetForStart();
    _emitConnectingState();

    try {
      await _connect();
    } catch (e) {
      debugPrint('[GeminiLive] Start failed: $e');
      _emitError('연결에 실패했습니다');
      _emitErrorState();
    }
  }

  Future<void> end() => _shutdownRunner.end();

  Future<void> dispose() => _shutdownRunner.dispose();
}
