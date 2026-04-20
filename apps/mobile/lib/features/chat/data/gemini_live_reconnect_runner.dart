import 'dart:async';

import 'package:flutter/foundation.dart';

import 'gemini_live_reconnect_coordinator.dart';

typedef GeminiLiveReconnectWait = Future<void> Function(Duration delay);

class GeminiLiveReconnectRunner {
  const GeminiLiveReconnectRunner({
    required GeminiLiveReconnectCoordinator coordinator,
    required bool Function() isActive,
    required Future<void> Function(String? handle) onConnect,
    required void Function() onExhausted,
    GeminiLiveReconnectWait wait = _defaultWait,
  })  : _coordinator = coordinator,
        _isActive = isActive,
        _onConnect = onConnect,
        _onExhausted = onExhausted,
        _wait = wait;

  final GeminiLiveReconnectCoordinator _coordinator;
  final bool Function() _isActive;
  final Future<void> Function(String? handle) _onConnect;
  final void Function() _onExhausted;
  final GeminiLiveReconnectWait _wait;

  void attemptReconnect() {
    if (!_isActive()) return;

    final decision = _coordinator.requestReconnect();
    switch (decision.status) {
      case GeminiLiveReconnectDecisionStatus.alreadyInProgress:
        return;
      case GeminiLiveReconnectDecisionStatus.exhausted:
        _onExhausted();
        return;
      case GeminiLiveReconnectDecisionStatus.scheduled:
        break;
    }

    final delay = decision.delay!;
    final attempt = decision.attempt!;
    debugPrint(
      '[GeminiLive] Reconnecting in ${delay.inMilliseconds}ms (attempt $attempt)',
    );

    unawaited(_waitAndReconnect(delay));
  }

  Future<void> _waitAndReconnect(Duration delay) async {
    await _wait(delay);
    if (!_isActive()) {
      _coordinator.markReconnectIdle();
      return;
    }

    try {
      await _onConnect(_coordinator.resumptionHandle);
    } catch (error) {
      debugPrint('[GeminiLive] Reconnect failed: $error');
      _coordinator.markReconnectIdle();
      if (_isActive()) attemptReconnect();
    }
  }
}

Future<void> _defaultWait(Duration delay) {
  return Future<void>.delayed(delay);
}
