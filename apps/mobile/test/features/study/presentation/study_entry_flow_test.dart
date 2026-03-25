import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/presentation/study_entry_flow.dart';

void main() {
  group('resolveStudyEntryDecision', () {
    test('returns resume flow for smart categories with incomplete session',
        () {
      final decision = resolveStudyEntryDecision(
        category: 'VOCABULARY',
        hasIncomplete: true,
        hasPreview: true,
      );

      expect(decision.action, StudyEntryActionKind.resumeOrNew);
      expect(decision.isTappable, isTrue);
    });

    test('returns preview flow for smart categories with preview data', () {
      final decision = resolveStudyEntryDecision(
        category: 'GRAMMAR',
        hasPreview: true,
      );

      expect(decision.action, StudyEntryActionKind.showPreview);
      expect(decision.isTappable, isTrue);
    });

    test('falls back to startQuiz when no preview (Day 1 user)', () {
      final decision = resolveStudyEntryDecision(
        category: 'VOCABULARY',
      );

      expect(decision.action, StudyEntryActionKind.startQuiz);
      expect(decision.isTappable, isTrue);
    });

    test('starts sentence arrange quiz directly with arrange mode', () {
      final decision = resolveStudyEntryDecision(
        category: 'SENTENCE_ARRANGE',
      );

      expect(decision.action, StudyEntryActionKind.startQuiz);
      expect(decision.mode, 'arrange');
    });

    test('GRAMMAR without preview starts basic quiz (not unavailable)', () {
      final decision = resolveStudyEntryDecision(
        category: 'GRAMMAR',
      );

      expect(decision.action, StudyEntryActionKind.startQuiz);
      expect(decision.isTappable, isTrue);
    });

    test('resume takes priority over preview', () {
      final decision = resolveStudyEntryDecision(
        category: 'VOCABULARY',
        hasIncomplete: true,
        hasPreview: true,
      );

      expect(decision.action, StudyEntryActionKind.resumeOrNew);
    });

    test('preview takes priority over basic quiz', () {
      final decision = resolveStudyEntryDecision(
        category: 'VOCABULARY',
        hasPreview: true,
      );

      expect(decision.action, StudyEntryActionKind.showPreview);
    });
  });
}
