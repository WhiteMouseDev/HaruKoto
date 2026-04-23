import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/special_quiz_flow_controller.dart';

void main() {
  group('SpecialQuizFlowController', () {
    test('reports initial progress and count labels', () {
      final controller = SpecialQuizFlowController();

      expect(controller.currentIndex, 0);
      expect(controller.answered, isFalse);
      expect(controller.isCorrect, isFalse);
      expect(controller.progressFor(4), 0.25);
      expect(controller.countLabelFor(4), '1/4');
      expect(controller.progressFor(0), 0);
      expect(controller.countLabelFor(0), '0/0');
    });

    test('accepts one answer and ignores duplicate submissions', () {
      final controller = SpecialQuizFlowController();

      final first = controller.answer(isCorrect: true);
      final duplicate = controller.answer(isCorrect: false);

      expect(first, SpecialQuizAnswerOutcome.answered);
      expect(duplicate, SpecialQuizAnswerOutcome.ignored);
      expect(controller.answered, isTrue);
      expect(controller.isCorrect, isTrue);
    });

    test('advances to the next question and resets answer state', () {
      final controller = SpecialQuizFlowController();
      controller.answer(isCorrect: false);

      final outcome = controller.advance(2);

      expect(outcome, SpecialQuizAdvanceOutcome.advanced);
      expect(controller.currentIndex, 1);
      expect(controller.answered, isFalse);
      expect(controller.isCorrect, isFalse);
      expect(controller.progressFor(2), 1);
      expect(controller.countLabelFor(2), '2/2');
    });

    test('returns completed without changing state on the final question', () {
      final controller = SpecialQuizFlowController();

      final outcome = controller.advance(1);

      expect(outcome, SpecialQuizAdvanceOutcome.completed);
      expect(controller.currentIndex, 0);
      expect(controller.answered, isFalse);
    });
  });
}
