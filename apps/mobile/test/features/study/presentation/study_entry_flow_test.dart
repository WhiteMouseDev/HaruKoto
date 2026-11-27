import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/core/constants/sizes.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_session_model.dart';
import 'package:harukoto_mobile/features/study/presentation/study_entry_flow.dart';
import 'package:harukoto_mobile/shared/widgets/app_sheet_handle.dart';

void main() {
  group('resolveStudyEntryDecision', () {
    test('returns resume flow for smart categories with incomplete session',
        () {
      final decision = resolveStudyEntryDecision(
        category: 'VOCABULARY',
        hasIncomplete: true,
        canShowPreview: true,
      );

      expect(decision.action, StudyEntryActionKind.resumeOrNew);
      expect(decision.isTappable, isTrue);
    });

    test('returns preview flow for smart categories with preview data', () {
      final decision = resolveStudyEntryDecision(
        category: 'GRAMMAR',
        canShowPreview: true,
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
        canShowPreview: true,
      );

      expect(decision.action, StudyEntryActionKind.resumeOrNew);
    });

    test('preview takes priority over basic quiz', () {
      final decision = resolveStudyEntryDecision(
        category: 'VOCABULARY',
        canShowPreview: true,
      );

      expect(decision.action, StudyEntryActionKind.showPreview);
    });
  });

  testWidgets('resume sheet uses the common shape and dismisses normally',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showResumeOrNewStudySheet(
                context,
                session: const IncompleteSessionModel(
                  id: 'saved-lesson',
                  quizType: 'VOCABULARY',
                  jlptLevel: 'N4',
                  totalQuestions: 10,
                  answeredCount: 3,
                  correctCount: 2,
                  startedAt: '2026-11-04T01:00:00Z',
                ),
                selectedCategory: 'VOCABULARY',
                jlptLevel: 'N4',
              ),
              child: const Text('이어풀기 열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('이어풀기 열기'));
    await tester.pumpAndSettle();
    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.shape, AppSizes.sheetShape);
    final handle = find.descendant(
      of: find.byType(AppSheetHandle),
      matching: find.byType(Container),
    );
    expect(tester.getSize(handle), const Size(40, 4));
    expect(find.text('이어서 학습하기'), findsOneWidget);
    expect(find.text('새로 시작하기'), findsOneWidget);

    await tester.tapAt(const Offset(300, 100));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
  });
}
