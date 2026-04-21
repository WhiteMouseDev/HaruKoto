import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_service.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_live_state_coordinator.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_state.dart';

void main() {
  group('VoiceCallLiveStateCoordinator', () {
    const coordinator = VoiceCallLiveStateCoordinator();

    test('maps connected state to clear error, stop ringtone, and start timer',
        () {
      final transition = coordinator.resolve(GeminiLiveState.connected);

      expect(transition.status, VoiceCallStatus.connected);
      expect(transition.clearErrorMessage, isTrue);
      expect(transition.stopRingtone, isTrue);
      expect(transition.startTimer, isTrue);
    });

    test('maps transient and terminal states without unexpected timer start',
        () {
      expect(
        coordinator.resolve(GeminiLiveState.connecting).status,
        VoiceCallStatus.connecting,
      );

      final ending = coordinator.resolve(GeminiLiveState.ending);
      expect(ending.status, VoiceCallStatus.ending);
      expect(ending.stopRingtone, isTrue);
      expect(ending.startTimer, isFalse);

      final ended = coordinator.resolve(GeminiLiveState.ended);
      expect(ended.status, VoiceCallStatus.ended);
      expect(ended.stopRingtone, isFalse);
      expect(ended.startTimer, isFalse);
    });

    test('maps error state to stop ringtone without clearing error message',
        () {
      final transition = coordinator.resolve(GeminiLiveState.error);

      expect(transition.status, VoiceCallStatus.error);
      expect(transition.clearErrorMessage, isFalse);
      expect(transition.stopRingtone, isTrue);
      expect(transition.startTimer, isFalse);
    });
  });
}
