import 'dart:io' show Platform;

bool isIosSimulatorEnvironment() {
  if (!Platform.isIOS) return false;

  final environment = Platform.environment;
  return hasIosSimulatorSignal(
    environment: environment,
    resolvedExecutable: Platform.resolvedExecutable,
  );
}

bool hasIosSimulatorSignal({
  required Map<String, String> environment,
  required String resolvedExecutable,
}) {
  return environment.containsKey('SIMULATOR_DEVICE_NAME') ||
      environment.containsKey('SIMULATOR_UDID') ||
      environment.containsKey('SIMULATOR_ROOT') ||
      environment.containsKey('SIMULATOR_HOST_HOME') ||
      resolvedExecutable.contains('/CoreSimulator/') ||
      environment.values.any((value) => value.contains('/CoreSimulator/'));
}
