import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_connection_service.dart';
import 'package:harukoto_mobile/features/chat/providers/voice_call_session_lifecycle.dart';

void main() {
  group('VoiceCallSessionLifecycle', () {
    test('stores the current request and generation freshness', () {
      final lifecycle = VoiceCallSessionLifecycle();
      const firstRequest = VoiceCallSessionRequest(characterId: 'first');
      const secondRequest = VoiceCallSessionRequest(characterId: 'second');

      final firstGeneration = lifecycle.begin(firstRequest);
      final secondGeneration = lifecycle.begin(secondRequest);

      expect(lifecycle.request, secondRequest);
      expect(lifecycle.isStale(firstGeneration), isTrue);
      expect(lifecycle.isStale(secondGeneration), isFalse);
    });

    test('markDisposed invalidates the active generation', () {
      final lifecycle = VoiceCallSessionLifecycle();
      final generation = lifecycle.begin(
        const VoiceCallSessionRequest(characterId: 'char-1'),
      );

      lifecycle.markDisposed();

      expect(lifecycle.isDisposed, isTrue);
      expect(lifecycle.isStale(generation), isTrue);
    });
  });
}
