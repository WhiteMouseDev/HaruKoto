import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/quiz_session_model.dart';
import 'package:harukoto_mobile/features/study/data/models/smart_preview_model.dart';
import 'package:harukoto_mobile/features/study/providers/quiz_progress_refresh_provider.dart';
import 'package:harukoto_mobile/features/study/providers/study_provider.dart';

void main() {
  test('refresh re-reads saved answers and every active category preview',
      () async {
    var answered = 0;
    var sessionReads = 0;
    final previewReads = <String, int>{};
    final container = ProviderContainer(overrides: [
      incompleteQuizProvider.overrideWith((ref) async {
        sessionReads++;
        return IncompleteSessionModel(
          id: 'persisted-session',
          quizType: 'VOCABULARY',
          jlptLevel: 'N5',
          totalQuestions: 10,
          answeredCount: answered,
          correctCount: answered,
          startedAt: '2026-10-19T01:00:00Z',
        );
      }),
      smartPreviewProvider.overrideWith((ref, params) async {
        previewReads.update(params.category, (count) => count + 1,
            ifAbsent: () => 1);
        return _preview();
      }),
    ]);
    addTearDown(container.dispose);
    // Home and its preview remain mounted while the quiz covers them.
    container.listen(incompleteQuizProvider, (_, __) {});
    for (final category in ['VOCABULARY', 'GRAMMAR']) {
      container.listen(
        smartPreviewProvider((category: category, jlptLevel: 'N5')),
        (_, __) {},
      );
    }
    expect((await container.read(incompleteQuizProvider.future))?.answeredCount,
        0);
    for (final category in ['VOCABULARY', 'GRAMMAR']) {
      await container.read(
          smartPreviewProvider((category: category, jlptLevel: 'N5')).future);
    }

    answered = 1;
    container.read(quizProgressRefreshProvider).refresh();
    expect((await container.read(incompleteQuizProvider.future))?.answeredCount,
        1);
    for (final category in ['VOCABULARY', 'GRAMMAR']) {
      await container.read(
          smartPreviewProvider((category: category, jlptLevel: 'N5')).future);
    }
    expect(sessionReads, 2);
    expect(previewReads, {'VOCABULARY': 2, 'GRAMMAR': 2});
  });
}

SmartPreviewModel _preview() => SmartPreviewModel.fromJson({
      'poolSize': {'newReady': 10, 'reviewDue': 0, 'retryDue': 0},
      'sessionDistribution': {'new': 10, 'review': 0, 'retry': 0, 'total': 10},
      'dailyGoal': 10,
      'todayCompleted': 0,
      'overallProgress': {
        'total': 100,
        'studied': 0,
        'mastered': 0,
        'percentage': 0
      },
    });
