import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_lifecycle_controller.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_reconnect_coordinator.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_session_lifecycle_runner.dart';

void main() {
  group('GeminiLiveSessionLifecycleRunner', () {
    test('start reports model validation errors without connecting', () async {
      var connectCalls = 0;
      final states = <String>[];
      final errors = <String>[];
      final runner = _buildRunner(
        connect: () async {
          connectCalls++;
        },
        states: states,
        errors: errors,
      );

      await runner.start(model: '');

      expect(connectCalls, 0);
      expect(errors, ['음성 모델이 설정되지 않았습니다']);
      expect(states, ['error']);
    });

    test('start marks the lifecycle active, resets reconnect, and connects',
        () async {
      final lifecycle = GeminiLiveLifecycleController()..markEnding();
      final reconnect = GeminiLiveReconnectCoordinator();
      reconnect.requestReconnect();
      var connectCalls = 0;
      final states = <String>[];
      final runner = _buildRunner(
        lifecycleController: lifecycle,
        reconnectCoordinator: reconnect,
        connect: () async {
          connectCalls++;
        },
        states: states,
      );

      await runner.start(model: 'gemini-live');

      expect(lifecycle.isActive, isTrue);
      expect(connectCalls, 1);
      expect(states, ['connecting']);
      expect(
        reconnect.requestReconnect().status,
        GeminiLiveReconnectDecisionStatus.scheduled,
      );
    });

    test('start emits a user-facing error when connect fails', () async {
      final states = <String>[];
      final errors = <String>[];
      final runner = _buildRunner(
        connect: () => throw StateError('boom'),
        states: states,
        errors: errors,
      );

      await runner.start(model: 'gemini-live');

      expect(errors, ['연결에 실패했습니다']);
      expect(states, ['connecting', 'error']);
    });

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

GeminiLiveSessionLifecycleRunner _buildRunner({
  GeminiLiveLifecycleController? lifecycleController,
  GeminiLiveReconnectCoordinator? reconnectCoordinator,
  Future<void> Function()? connect,
  Future<void> Function()? stopRecording,
  Future<void> Function()? disposeAudio,
  Future<void> Function()? closeTransport,
  void Function()? flushTranscripts,
  List<String>? states,
  List<String>? errors,
}) {
  final stateEvents = states ?? <String>[];
  final errorEvents = errors ?? <String>[];
  return GeminiLiveSessionLifecycleRunner(
    lifecycleController: lifecycleController ?? GeminiLiveLifecycleController(),
    reconnectCoordinator:
        reconnectCoordinator ?? GeminiLiveReconnectCoordinator(),
    connect: connect ?? () async {},
    stopRecording: stopRecording ?? () async {},
    disposeAudio: disposeAudio ?? () async {},
    closeTransport: closeTransport ?? () async {},
    flushTranscripts: flushTranscripts ?? () {},
    emitConnectingState: () => stateEvents.add('connecting'),
    emitErrorState: () => stateEvents.add('error'),
    emitEndingState: () => stateEvents.add('ending'),
    emitEndedState: () => stateEvents.add('ended'),
    emitError: errorEvents.add,
  );
}
