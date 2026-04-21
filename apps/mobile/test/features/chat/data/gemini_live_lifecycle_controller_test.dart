import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/gemini_live_lifecycle_controller.dart';

void main() {
  group('GeminiLiveLifecycleController', () {
    test('tracks active state across start and end', () {
      final controller = GeminiLiveLifecycleController();

      expect(controller.isActive, isTrue);

      controller.markEnding();
      expect(controller.isActive, isFalse);

      controller.markStarted();
      expect(controller.isActive, isTrue);
    });

    test('dispose permanently marks the lifecycle inactive', () {
      final controller = GeminiLiveLifecycleController();

      controller.markDisposed();
      controller.markStarted();

      expect(controller.isDisposed, isTrue);
      expect(controller.isActive, isFalse);
    });

    test('tracks muted state independently from lifecycle state', () {
      final controller = GeminiLiveLifecycleController();

      controller.isMuted = true;
      controller.markEnding();

      expect(controller.isMuted, isTrue);
      expect(controller.isActive, isFalse);
    });
  });
}
