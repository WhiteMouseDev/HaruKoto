import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_lifecycle_controller.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_session_shutdown_runner.dart';

void main() {
  group('GeminiLiveSessionShutdownRunner', () {
    test('end stops recording, closes transport, and emits terminal states',
        () async {
      final lifecycle = GeminiLiveLifecycleController();
      final actions = <String>[];
      final states = <String>[];
      final runner = _buildRunner(
        lifecycleController: lifecycle,
        stopRecording: () async => actions.add('stopRecording'),
        closeTransport: () async => actions.add('closeTransport'),
        flushTranscripts: () => actions.add('flushTranscripts'),
        states: states,
      );

      await runner.end();

      expect(lifecycle.isActive, isFalse);
      expect(actions, ['flushTranscripts', 'stopRecording', 'closeTransport']);
      expect(states, ['ending', 'ended']);
    });

    test('dispose disposes audio and closes transport without emitting states',
        () async {
      final lifecycle = GeminiLiveLifecycleController();
      final actions = <String>[];
      final states = <String>[];
      final runner = _buildRunner(
        lifecycleController: lifecycle,
        disposeAudio: () async => actions.add('disposeAudio'),
        closeTransport: () async => actions.add('closeTransport'),
        states: states,
      );

      await runner.dispose();

      expect(lifecycle.isDisposed, isTrue);
      expect(lifecycle.isActive, isFalse);
      expect(actions, ['disposeAudio', 'closeTransport']);
      expect(states, isEmpty);
    });
  });
}

GeminiLiveSessionShutdownRunner _buildRunner({
  GeminiLiveLifecycleController? lifecycleController,
  Future<void> Function()? stopRecording,
  Future<void> Function()? disposeAudio,
  Future<void> Function()? closeTransport,
  void Function()? flushTranscripts,
  List<String>? states,
}) {
  final stateEvents = states ?? <String>[];
  return GeminiLiveSessionShutdownRunner(
    lifecycleController: lifecycleController ?? GeminiLiveLifecycleController(),
    stopRecording: stopRecording ?? () async {},
    disposeAudio: disposeAudio ?? () async {},
    closeTransport: closeTransport ?? () async {},
    flushTranscripts: flushTranscripts ?? () {},
    emitEndingState: () => stateEvents.add('ending'),
    emitEndedState: () => stateEvents.add('ended'),
  );
}
