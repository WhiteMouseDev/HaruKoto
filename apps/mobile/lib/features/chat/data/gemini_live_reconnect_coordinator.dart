enum GeminiLiveReconnectDecisionStatus {
  scheduled,
  alreadyInProgress,
  exhausted,
}

class GeminiLiveReconnectDecision {
  const GeminiLiveReconnectDecision._({
    required this.status,
    this.delay,
    this.attempt,
  });

  const GeminiLiveReconnectDecision.scheduled({
    required Duration delay,
    required int attempt,
  }) : this._(
          status: GeminiLiveReconnectDecisionStatus.scheduled,
          delay: delay,
          attempt: attempt,
        );

  const GeminiLiveReconnectDecision.alreadyInProgress()
      : this._(status: GeminiLiveReconnectDecisionStatus.alreadyInProgress);

  const GeminiLiveReconnectDecision.exhausted()
      : this._(status: GeminiLiveReconnectDecisionStatus.exhausted);

  final GeminiLiveReconnectDecisionStatus status;
  final Duration? delay;
  final int? attempt;
}

class GeminiLiveReconnectCoordinator {
  GeminiLiveReconnectCoordinator({
    this.maxReconnectAttempts = 3,
  });

  final int maxReconnectAttempts;

  int _connectionGeneration = 0;
  int _reconnectAttempts = 0;
  bool _reconnecting = false;
  String? _resumptionHandle;

  String? get resumptionHandle => _resumptionHandle;

  int beginConnection() {
    _connectionGeneration++;
    return _connectionGeneration;
  }

  bool isCurrentConnection(int generation) {
    return generation == _connectionGeneration;
  }

  void resetForStart() {
    _reconnecting = false;
  }

  void markConnected() {
    _reconnectAttempts = 0;
    _reconnecting = false;
  }

  void markReconnectIdle() {
    _reconnecting = false;
  }

  void updateResumptionHandle(String? handle) {
    _resumptionHandle = handle;
  }

  GeminiLiveReconnectDecision requestReconnect() {
    if (_reconnecting) {
      return const GeminiLiveReconnectDecision.alreadyInProgress();
    }
    if (_reconnectAttempts >= maxReconnectAttempts) {
      return const GeminiLiveReconnectDecision.exhausted();
    }

    _reconnecting = true;
    _reconnectAttempts++;
    return GeminiLiveReconnectDecision.scheduled(
      delay: Duration(milliseconds: 1000 * (1 << (_reconnectAttempts - 1))),
      attempt: _reconnectAttempts,
    );
  }
}
