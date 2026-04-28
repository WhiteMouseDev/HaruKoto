import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_audio_environment_io.dart';

void main() {
  group('hasIosSimulatorSignal', () {
    test('detects simulator environment variables', () {
      expect(
        hasIosSimulatorSignal(
          environment: const {'SIMULATOR_UDID': 'device-id'},
          resolvedExecutable: '/private/var/containers/Runner.app/Runner',
        ),
        isTrue,
      );
    });

    test('detects CoreSimulator executable paths', () {
      expect(
        hasIosSimulatorSignal(
          environment: const {},
          resolvedExecutable:
              '/Users/me/Library/Developer/CoreSimulator/Devices/id/Runner',
        ),
        isTrue,
      );
    });

    test('does not flag physical device paths', () {
      expect(
        hasIosSimulatorSignal(
          environment: const {'HOME': '/private/var/mobile/Containers/Data'},
          resolvedExecutable:
              '/private/var/containers/Bundle/Runner.app/Runner',
        ),
        isFalse,
      );
    });
  });
}
