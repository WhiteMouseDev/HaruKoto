import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_service.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_live_state_coordinator.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_state.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_state_reducer.dart';

void main() {
  group('VoiceCallSessionStateReducer', () {
    const reducer = VoiceCallSessionStateReducer();

    test('applies failure state with the provided error message', () {
      final next = reducer.fail(
        const VoiceCallSessionState(status: VoiceCallStatus.connected),
        'network error',
      );

      expect(next.status, VoiceCallStatus.error);
      expect(next.errorMessage, 'network error');
    });

    test('applies non-retryable failure state', () {
      final next = reducer.fail(
        const VoiceCallSessionState(status: VoiceCallStatus.connected),
        'quota exceeded',
        canRetry: false,
      );

      expect(next.status, VoiceCallStatus.error);
      expect(next.canRetry, isFalse);
    });

    test('toggles local call controls', () {
      const state = VoiceCallSessionState(isMuted: false, showSubtitle: true);

      final muted = reducer.toggleMute(state);
      final subtitleHidden = reducer.toggleSubtitle(state);

      expect(muted.isMuted, isTrue);
      expect(subtitleHidden.showSubtitle, isFalse);
    });

    test('applies live transition and clears stale errors when requested', () {
      const state = VoiceCallSessionState(
        status: VoiceCallStatus.error,
        errorMessage: 'old error',
      );

      final next = reducer.applyLiveTransition(
        state,
        const VoiceCallLiveStateTransition(
          status: VoiceCallStatus.connected,
          clearErrorMessage: true,
        ),
      );

      expect(next.status, VoiceCallStatus.connected);
      expect(next.errorMessage, isNull);
    });

    test('appends AI text and clears it for assistant transcript entries', () {
      var state = reducer.appendAiTextDelta(
        const VoiceCallSessionState(),
        'こん',
      );
      state = reducer.appendAiTextDelta(state, 'にちは');

      expect(state.currentAiText, 'こんにちは');

      final afterUserEntry = reducer.applyTranscriptEntry(
        state,
        const TranscriptEntry(role: 'user', text: 'もしもし'),
      );
      final afterAssistantEntry = reducer.applyTranscriptEntry(
        state,
        const TranscriptEntry(role: 'assistant', text: 'こんにちは'),
      );

      expect(afterUserEntry.currentAiText, 'こんにちは');
      expect(afterAssistantEntry.currentAiText, isEmpty);
    });

    test('sets error message and increments duration', () {
      final errored = reducer.setErrorMessage(
        const VoiceCallSessionState(),
        'microphone unavailable',
      );
      final ticked = reducer.incrementDuration(
        const VoiceCallSessionState(callDurationSeconds: 41),
      );

      expect(errored.errorMessage, 'microphone unavailable');
      expect(ticked.callDurationSeconds, 42);
    });
  });
}
