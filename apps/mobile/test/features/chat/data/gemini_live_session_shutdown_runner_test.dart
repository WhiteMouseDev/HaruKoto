import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_lifecycle_controller.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_session_shutdown_runner.dart';

void main() {
  group('GeminiLiveSessionShutdownRunner', () {
    for (final dispose in [false, true]) {
      test('${dispose ? 'dispose' : 'end'} closes the socket while audio stops',
          () async {
        final audioStopped = Completer<void>();
        var closed = false;
        final runner = _buildRunner(
          stopRecording: () => audioStopped.future,
          disposeAudio: () => audioStopped.future,
          closeTransport: () async => closed = true,
        );
        final closing = dispose ? runner.dispose() : runner.end();
        await Future<void>.delayed(Duration.zero);
        expect(closed, isTrue);
        audioStopped.complete();
        await closing;
      });

      test('${dispose ? 'dispose' : 'end'} closes the socket if audio fails',
          () async {
        var closed = false;
        final runner = _buildRunner(
          stopRecording: () async => throw StateError('audio stop failed'),
          disposeAudio: () async => throw StateError('audio dispose failed'),
          closeTransport: () async => closed = true,
        );

        await expectLater(dispose ? runner.dispose() : runner.end(),
            throwsA(isA<StateError>()));
        expect(closed, isTrue);
      });
    }

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
      expect(actions, ['flushTranscripts', 'closeTransport', 'stopRecording']);
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
      expect(actions, ['closeTransport', 'disposeAudio']);
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
