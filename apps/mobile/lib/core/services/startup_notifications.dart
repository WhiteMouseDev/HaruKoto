enum StartupNotificationStage { initialize, schedule }

/// Only safe metadata is retained: plugin messages/details may contain payloads.
class StartupNotificationFailure implements Exception {
  const StartupNotificationFailure({
    required this.stage,
    required this.exceptionType,
    required this.stackTrace,
  });

  final StartupNotificationStage stage;
  final String exceptionType;
  final StackTrace stackTrace;

  @override
  String toString() =>
      'Notification startup ${stage.name} failed ($exceptionType).';
}

/// Startup-only boundary; normal settings changes still propagate failures.
class StartupNotifications {
  bool _initialized = false;
  final List<StartupNotificationFailure> _failures = [];

  List<StartupNotificationFailure> get failures => List.unmodifiable(_failures);

  Future<void> initialize(Future<void> Function() initialize) async {
    try {
      await initialize();
      _initialized = true;
    } on Exception catch (error, stackTrace) {
      _record(StartupNotificationStage.initialize, error, stackTrace);
    }
  }

  Future<void> applySettings(Future<void> Function() applySettings) async {
    if (!_initialized) return;
    try {
      await applySettings();
    } on Exception catch (error, stackTrace) {
      _record(StartupNotificationStage.schedule, error, stackTrace);
    }
  }

  void _record(
    StartupNotificationStage stage,
    Exception error,
    StackTrace stackTrace,
  ) {
    _failures.add(StartupNotificationFailure(
      stage: stage,
      exceptionType: error.runtimeType.toString(),
      stackTrace: stackTrace,
    ));
  }
}
