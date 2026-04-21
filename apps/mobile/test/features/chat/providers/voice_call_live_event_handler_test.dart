import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_service.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_live_event_handler.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_resources.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_state.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_timer.dart';

void main() {
  group('VoiceCallLiveEventHandler', () {
    test('applies connected state and starts guarded timer', () async {
      var state = const VoiceCallSessionState(
        status: VoiceCallStatus.error,
        errorMessage: 'old error',
      );
      var disposed = false;
      final ringtone = _FakeVoiceCallRingtonePlayer();
      final timer = _FakeVoiceCallSessionTimer();
      final resources = VoiceCallSessionResources(ringtone, timer: timer);
      final handler = VoiceCallLiveEventHandler(
        getState: () => state,
        setState: (nextState) => state = nextState,
        getResources: () => resources,
        isDisposed: () => disposed,
      );

      handler.handleStateChange(GeminiLiveState.connected);
      await Future<void>.delayed(Duration.zero);

      expect(state.status, VoiceCallStatus.connected);
      expect(state.errorMessage, isNull);
      expect(ringtone.stopCalls, 1);
      expect(timer.startCalls, 1);

      timer.tick();
      expect(state.callDurationSeconds, 1);

      disposed = true;
      timer.tick();
      expect(state.callDurationSeconds, 1);
    });

    test('applies text transcript and error callbacks to state', () {
      var state = const VoiceCallSessionState();
      final handler = VoiceCallLiveEventHandler(
        getState: () => state,
        setState: (nextState) => state = nextState,
        getResources: () => null,
        isDisposed: () => false,
      );

      handler.appendAiTextDelta('こん');
      handler.appendAiTextDelta('にちは');
      expect(state.currentAiText, 'こんにちは');

      handler.handleTranscriptEntry(
        const TranscriptEntry(role: 'user', text: 'もしもし'),
      );
      expect(state.currentAiText, 'こんにちは');

      handler.handleTranscriptEntry(
        const TranscriptEntry(role: 'assistant', text: 'こんにちは'),
      );
      expect(state.currentAiText, isEmpty);

      handler.setErrorMessage('network error');
      expect(state.errorMessage, 'network error');
    });
  });
}

class _FakeVoiceCallRingtonePlayer implements VoiceCallRingtonePlayer {
  int stopCalls = 0;

  @override
  Future<void> startLoop() async {}

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<void> dispose() async {}
}

class _FakeVoiceCallSessionTimer implements VoiceCallSessionTimer {
  int startCalls = 0;
  void Function()? onTick;

  @override
  void start(void Function() onTick) {
    startCalls++;
    this.onTick = onTick;
  }

  void tick() {
    onTick?.call();
  }

  @override
  void stop() {}

  @override
  void dispose() {}
}
