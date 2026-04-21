import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_lifecycle_controller.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_reconnect_coordinator.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_session_lifecycle_runner_factory.dart';

void main() {
  group('GeminiLiveSessionLifecycleRunnerFactory', () {
    test('builds a lifecycle runner with start and shutdown delegates',
        () async {
      const factory = GeminiLiveSessionLifecycleRunnerFactory();
      final lifecycle = GeminiLiveLifecycleController();
      final reconnect = GeminiLiveReconnectCoordinator();
      final actions = <String>[];
      final states = <String>[];
      final errors = <String>[];

      final runner = factory.build(
        lifecycleController: lifecycle,
        reconnectCoordinator: reconnect,
        connect: () async => actions.add('connect'),
        stopRecording: () async => actions.add('stopRecording'),
        disposeAudio: () async => actions.add('disposeAudio'),
        closeTransport: () async => actions.add('closeTransport'),
        flushTranscripts: () => actions.add('flushTranscripts'),
        emitConnectingState: () => states.add('connecting'),
        emitErrorState: () => states.add('error'),
        emitEndingState: () => states.add('ending'),
        emitEndedState: () => states.add('ended'),
        emitError: errors.add,
      );

      await runner.start(model: 'gemini-live');
      await runner.end();
      await runner.dispose();

      expect(errors, isEmpty);
      expect(
        actions,
        [
          'connect',
          'flushTranscripts',
          'stopRecording',
          'closeTransport',
          'disposeAudio',
          'closeTransport',
        ],
      );
      expect(states, ['connecting', 'ending', 'ended']);
      expect(lifecycle.isDisposed, isTrue);
    });

    test('preserves start validation behavior', () async {
      const factory = GeminiLiveSessionLifecycleRunnerFactory();
      final actions = <String>[];
      final states = <String>[];
      final errors = <String>[];

      final runner = factory.build(
        lifecycleController: GeminiLiveLifecycleController(),
        reconnectCoordinator: GeminiLiveReconnectCoordinator(),
        connect: () async => actions.add('connect'),
        stopRecording: () async {},
        disposeAudio: () async {},
        closeTransport: () async {},
        flushTranscripts: () {},
        emitConnectingState: () => states.add('connecting'),
        emitErrorState: () => states.add('error'),
        emitEndingState: () => states.add('ending'),
        emitEndedState: () => states.add('ended'),
        emitError: errors.add,
      );

      await runner.start(model: '');

      expect(actions, isEmpty);
      expect(errors, ['음성 모델이 설정되지 않았습니다']);
      expect(states, ['error']);
    });
  });
}
