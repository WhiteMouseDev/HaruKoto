import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harukoto_mobile/features/study/presentation/lesson_page.dart';
import 'package:harukoto_mobile/features/study/providers/lesson_session_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fixtures/lesson_activity_fixture.dart';

void main() {
  testWidgets(
      'real reorder Confirm then immediate X preserves one answer and activity on cold resume',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = ActivityRepositoryFixture()..failures = 20;
    final detail = activityDetail(recognition: false, reorderCount: 2);
    final h = ActivityHarness(
        preferences: prefs, activityRepository: repository, detail: detail);
    await h.start();
    await h.controller.completeMatching(detail: detail);
    final router = GoRouter(initialLocation: '/home', routes: [
      GoRoute(
          path: '/home',
          builder: (context, state) => Scaffold(
                  body: TextButton(
                onPressed: () => context.push('/lesson'),
                child: const Text('Open lesson'),
              ))),
      GoRoute(
          path: '/lesson',
          builder: (context, state) =>
              const LessonPage(lessonId: activityLesson)),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: h.container,
        child: MaterialApp.router(routerConfig: router)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open lesson'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('水'));
    await tester.pump();
    await tester.tap(find.text('です'));
    await tester.pump();
    await tester.tap(find.text('확인'));
    // No pump advances the previous 300ms delay before close begins.
    expect(h.state.answers[2]?['submittedOrder'], ['水', 'です']);
    expect(h.state.reorderIndex, 1);
    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pumpAndSettle();
    expect(find.byType(LessonPage), findsNothing);
    expect(await h.controller.flush(), isTrue);
    final pending = await h.store.pendingActivities(activityOwner);
    expect(pending, hasLength(1));
    final frozen = canonicalActivity(pending.single.request);
    expect(pending.single.request.kind, 'SENTENCE_REORDER');
    expect(pending.single.request.answer, {
      'questionOrder': 2,
      'submittedOrder': ['水', 'です']
    });
    expect(h.study.submissions, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    h.dispose();

    final cold = ActivityHarness(
        preferences: prefs, activityRepository: repository, detail: detail);
    addTearDown(cold.dispose);
    await cold.controller.initialize(detail);
    expect(cold.state.restored, isTrue);
    expect(cold.state.step, LessonStep.sentenceReorder);
    expect(cold.state.reorderIndex, 1);
    expect(cold.state.answers[2]?['submittedOrder'], ['水', 'です']);
    await cold.controller.flush();
    final recovered = await cold.store.pendingActivities(activityOwner);
    expect(recovered, hasLength(1));
    expect(canonicalActivity(recovered.single.request), frozen);
    expect(cold.study.submissions, 0);
    expect(tester.takeException(), isNull);
  });
}
