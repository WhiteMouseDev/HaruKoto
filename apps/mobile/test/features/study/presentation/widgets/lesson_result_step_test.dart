import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_result_step.dart';

void main() {
  group('LessonResultStep', () {
    testWidgets('shows SRS registration banner on completed result',
        (tester) async {
      var doneCalled = false;
      var retryCalled = false;

      await _pumpLessonResultStep(
        tester,
        result: const LessonSubmitResultModel(
          scoreCorrect: 5,
          scoreTotal: 5,
          results: [],
          status: 'COMPLETED',
          srsItemsRegistered: 6,
        ),
        onDone: () {
          doneCalled = true;
        },
        onRetry: () {
          retryCalled = true;
        },
      );
      await tester.pumpAndSettle();

      expect(find.text('100%'), findsOneWidget);
      expect(find.text('5/5 정답'), findsOneWidget);
      expect(find.text('6개 항목이 복습 예약되었습니다'), findsOneWidget);
      expect(find.text('학습으로 돌아가기'), findsOneWidget);
      expect(find.text('다시 풀기'), findsOneWidget);

      await tester.tap(find.text('학습으로 돌아가기'));
      await tester.pump();

      expect(doneCalled, isTrue);

      await tester.tap(find.text('다시 풀기'));
      await tester.pump();

      expect(retryCalled, isTrue);
    });

    testWidgets('hides SRS registration banner when no item is registered',
        (tester) async {
      await _pumpLessonResultStep(
        tester,
        result: const LessonSubmitResultModel(
          scoreCorrect: 5,
          scoreTotal: 5,
          results: [],
          status: 'COMPLETED',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('5/5 정답'), findsOneWidget);
      expect(find.textContaining('복습 예약되었습니다'), findsNothing);
    });
  });
}

Future<void> _pumpLessonResultStep(
  WidgetTester tester, {
  required LessonSubmitResultModel result,
  VoidCallback? onDone,
  VoidCallback? onRetry,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: LessonResultStep(
          result: result,
          detail: _detail,
          onDone: onDone ?? () {},
          onRetry: onRetry ?? () {},
        ),
      ),
    ),
  );
}

const _detail = LessonDetailModel(
  id: 'lesson-3',
  lessonNo: 3,
  chapterLessonNo: 3,
  title: '이야기 주제 세우기',
  topic: 'topic',
  estimatedMinutes: 10,
  content: LessonContentModel(
    reading: ReadingModel(script: []),
    questions: [],
  ),
  vocabItems: [],
  grammarItems: [],
);
