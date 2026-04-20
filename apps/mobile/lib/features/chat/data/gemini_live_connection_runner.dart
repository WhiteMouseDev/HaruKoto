import 'package:flutter/foundation.dart';

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
  })  : _reconnectCoordinator = reconnectCoordinator,
        _isActive = isActive,
        _onMessage = onMessage,
        _onReconnect = onReconnect;

  final GeminiLiveTransport transport;
  final GeminiLiveReconnectCoordinator _reconnectCoordinator;
  final bool Function() _isActive;
  final void Function(dynamic raw) _onMessage;
  final void Function() _onReconnect;

  Future<void> connect(GeminiLiveConnectionInput input) async {
    final uri = input.uri;
    debugPrint(
      '[GeminiLive] Connecting to: ${uri.scheme}://${uri.host}${uri.path}',
    );
    debugPrint(
      '[GeminiLive] Token prefix: ${input.token.substring(0, input.token.length.clamp(0, 30))}...',
    );
    debugPrint('[GeminiLive] Model: ${input.model}');

    final generation = _reconnectCoordinator.beginConnection();

    await transport.connect(
      uri,
      onMessage: _onMessage,
      onError: (error) {
        debugPrint('[GeminiLive] WebSocket error: $error');
        if (_reconnectCoordinator.isCurrentConnection(generation)) {
          _onReconnect();
        }
      },
      onDone: () {
        debugPrint('[GeminiLive] WebSocket closed');
        if (_reconnectCoordinator.isCurrentConnection(generation) &&
            _isActive()) {
          _onReconnect();
        }
      },
    );
  }
}
