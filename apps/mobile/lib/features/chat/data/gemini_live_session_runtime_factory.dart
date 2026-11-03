import 'gemini_live_audio_session.dart';
import 'gemini_live_connection_runner.dart';
import 'gemini_live_events.dart';
import 'gemini_live_greeting_sender.dart';
import 'gemini_live_inbound_dispatcher.dart';
import 'gemini_live_lifecycle_controller.dart';
import 'gemini_live_message_handler.dart';
import 'gemini_live_reconnect_coordinator.dart';
import 'gemini_live_reconnect_runner.dart';
import 'gemini_live_session_connector.dart';
import 'gemini_live_setup_complete_handler.dart';
import 'gemini_live_setup_sender.dart';
import 'gemini_live_transcript.dart';
import 'gemini_live_transport.dart';

class GeminiLiveSessionRuntime {
  const GeminiLiveSessionRuntime._({
    required GeminiLiveConnectionInput connectionInput,
    required GeminiLiveSessionConnector sessionConnector,
    required GeminiLiveInboundDispatcher inboundDispatcher,
    required GeminiLiveSetupCompleteHandler setupCompleteHandler,
  })  : _connectionInput = connectionInput,
        _sessionConnector = sessionConnector,
        _inboundDispatcher = inboundDispatcher,
        _setupCompleteHandler = setupCompleteHandler;

  final GeminiLiveConnectionInput _connectionInput;
  final GeminiLiveSessionConnector _sessionConnector;
  final GeminiLiveInboundDispatcher _inboundDispatcher;
  final GeminiLiveSetupCompleteHandler _setupCompleteHandler;

  Future<void> connect() {
    return _sessionConnector.connect(_connectionInput);
  }

  void dispatch(dynamic raw) {
    _inboundDispatcher.dispatch(raw);
  }

  void cancelPendingGreeting() => _setupCompleteHandler.cancelPendingGreeting();
}

class GeminiLiveSessionRuntimeFactory {
  const GeminiLiveSessionRuntimeFactory();

  GeminiLiveSessionRuntime build({
    required String wsUri,
    required String token,
    required String model,
    required GeminiLiveTransport transport,
    required GeminiLiveReconnectCoordinator reconnectCoordinator,
    required GeminiLiveLifecycleController lifecycleController,
    required GeminiLiveSetupSender setupSender,
    required GeminiLiveGreetingSender greetingSender,
    required GeminiLiveAudioSession audioSession,
    required GeminiLiveMessageHandler messageHandler,
    required void Function(GeminiLiveState state) emitState,
    required void Function(String message) emitError,
    required void Function(String text) onAiTextDelta,
    required void Function(TranscriptEntry entry) onTranscriptEntry,
    required void Function(String base64Data) onAudioChunk,
    Future<String> Function()? refreshToken,
  }) {
    final connectionInput = GeminiLiveConnectionInput(
      wsUri: wsUri,
      token: token,
      model: model,
    );
    late final GeminiLiveReconnectRunner reconnectRunner;
    late final GeminiLiveInboundDispatcher inboundDispatcher;

    void reconnect() {
      if (!lifecycleController.isActive) return;
      emitState(GeminiLiveState.connecting);
      reconnectRunner.attemptReconnect();
    }

    final setupCompleteHandler = GeminiLiveSetupCompleteHandler(
      reconnectCoordinator: reconnectCoordinator,
      greetingSender: greetingSender,
      preparePlayback: audioSession.preparePlayback,
      startRecording: audioSession.startRecording,
      emitState: emitState,
    );
    final connectionRunner = GeminiLiveConnectionRunner(
      transport: transport,
      reconnectCoordinator: reconnectCoordinator,
      isActive: () => lifecycleController.isActive,
      onMessage: (raw) => inboundDispatcher.dispatch(raw),
      onReconnect: reconnect,
    );
    final sessionConnector = GeminiLiveSessionConnector(
      connectionRunner: connectionRunner,
      reconnectCoordinator: reconnectCoordinator,
      setupSender: setupSender,
    );
    reconnectRunner = GeminiLiveReconnectRunner(
      coordinator: reconnectCoordinator,
      isActive: () => lifecycleController.isActive,
      onConnect: (handle) async {
        var reconnectInput = connectionInput;
        if (refreshToken != null) {
          final token =
              await refreshToken().timeout(const Duration(seconds: 10));
          // Ending the call while the request is pending must not open a new
          // socket. Future.timeout also discards any token arriving late.
          if (!lifecycleController.isActive) return;
          if (token.trim().isEmpty) {
            throw StateError('Live token refresh returned an empty token');
          }
          // Only credentials change. Resumption must use the original model,
          // endpoint and setup even if a newer model is deployed mid-call.
          reconnectInput = GeminiLiveConnectionInput(
            wsUri: connectionInput.wsUri,
            token: token,
            model: connectionInput.model,
          );
        }
        if (!lifecycleController.isActive) return;
        return sessionConnector.connect(
          reconnectInput,
          resumptionHandle: reconnectCoordinator.resumptionHandle ?? handle,
        );
      },
      onExhausted: () {
        emitError('연결이 끊어졌습니다');
        emitState(GeminiLiveState.error);
      },
    );
    inboundDispatcher = GeminiLiveInboundDispatcher(
      messageHandler: messageHandler,
      isActive: () => lifecycleController.isActive,
      onSetupComplete: setupCompleteHandler.handle,
      onUpdateResumptionHandle: reconnectCoordinator.updateResumptionHandle,
      onReconnect: reconnect,
      onAiTextDelta: onAiTextDelta,
      onTranscriptEntry: onTranscriptEntry,
      onAudioChunk: onAudioChunk,
      onModelTurnComplete: setupCompleteHandler.handleModelTurnComplete,
    );

    return GeminiLiveSessionRuntime._(
      connectionInput: connectionInput,
      sessionConnector: sessionConnector,
      inboundDispatcher: inboundDispatcher,
      setupCompleteHandler: setupCompleteHandler,
    );
  }
}
