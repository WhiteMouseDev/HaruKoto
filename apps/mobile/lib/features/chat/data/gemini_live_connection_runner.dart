import 'dart:async';

import 'package:flutter/foundation.dart';

import 'gemini_live_protocol.dart';
import 'gemini_live_reconnect_coordinator.dart';
import 'gemini_live_transport.dart';

class GeminiLiveConnectionInput {
  const GeminiLiveConnectionInput({
    required this.wsUri,
    required this.token,
    required this.model,
  });

  final String wsUri;
  final String token;
  final String model;

  Uri get uri => Uri.parse('$wsUri?access_token=$token');
}

class GeminiLiveConnectionRunner {
  const GeminiLiveConnectionRunner({
    required this.transport,
    required GeminiLiveReconnectCoordinator reconnectCoordinator,
    required bool Function() isActive,
    required void Function(dynamic raw) onMessage,
    required void Function() onReconnect,
    Duration connectionTimeout = const Duration(seconds: 12),
  })  : _reconnectCoordinator = reconnectCoordinator,
        _isActive = isActive,
        _onMessage = onMessage,
        _onReconnect = onReconnect,
        _connectionTimeout = connectionTimeout;

  final GeminiLiveTransport transport;
  final GeminiLiveReconnectCoordinator _reconnectCoordinator;
  final bool Function() _isActive;
  final void Function(dynamic raw) _onMessage;
  final void Function() _onReconnect;
  final Duration _connectionTimeout;

  Future<void> connect(
    GeminiLiveConnectionInput input, {
    required void Function() sendSetup,
  }) async {
    final uri = input.uri;
    debugPrint(
      '[GeminiLive] Connecting to: ${uri.scheme}://${uri.host}${uri.path}',
    );
    debugPrint('[GeminiLive] Model: ${input.model}');

    final generation = _reconnectCoordinator.beginConnection();
    final setupComplete = Completer<void>();
    var disconnected = false;

    bool isCurrent() =>
        _isActive() && _reconnectCoordinator.isCurrentConnection(generation);

    void handleDisconnect(Object error) {
      if (!isCurrent() || disconnected) return;
      disconnected = true;
      if (!setupComplete.isCompleted) {
        // The caller owns this attempt until setup completes. Failing it lets
        // the reconnect runner release its in-progress flag and retry.
        setupComplete.completeError(error);
      } else {
        _onReconnect();
      }
    }

    Future<void> openAndSendSetup() async {
      await transport.connect(
        uri,
        onMessage: (raw) {
          if (!isCurrent() || disconnected) return;
          _onMessage(raw);
          if (!setupComplete.isCompleted && _isSetupComplete(raw)) {
            setupComplete.complete();
          }
        },
        onError: handleDisconnect,
        onDone: () => handleDisconnect(StateError('Live connection closed')),
      );
      if (!isCurrent() || disconnected) {
        throw StateError('Live connection was cancelled');
      }
      sendSetup();
    }

    try {
      // Start listening for setup failures before opening the transport so an
      // early close cannot leave an unhandled completer error.
      await Future.wait<void>(
        [setupComplete.future, openAndSendSetup()],
        eagerError: true,
      ).timeout(_connectionTimeout);
    } catch (_) {
      if (_reconnectCoordinator.isCurrentConnection(generation)) {
        _reconnectCoordinator.invalidateConnection(generation);
        // A socket that never became ready must not extend the deadline while
        // closing. close() invalidates its callbacks before awaiting cleanup.
        unawaited(transport.close().catchError((Object error) {
          debugPrint('[GeminiLive] Socket cleanup failed: $error');
        }));
      }
      rethrow;
    }
  }

  bool _isSetupComplete(dynamic raw) {
    try {
      return GeminiLiveProtocol.parseMessage(raw)
              ?.containsKey('setupComplete') ??
          false;
    } on FormatException {
      return false;
    }
  }
}
