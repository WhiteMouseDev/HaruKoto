import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_activity_pending_banner.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../fixtures/lesson_activity_fixture.dart';

void main() {
  testWidgets('server ACK only clears pending, failure retry reuses same event',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = ActivityRepositoryFixture()..failures = 1;
    final h =
        ActivityHarness(preferences: prefs, activityRepository: repository);
    addTearDown(h.dispose);
    final request = activityDraft();
    await h.store.writeCheckpointAndActivities(activityOwner, activityLesson,
        'checkpoint', request.attemptId, [request]);
    // The original lesson is gone; only its account-level receipt queue remains.
    await h.store.remove(activityOwner, activityLesson);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: h.container,
        child: const MaterialApp(
            home: Scaffold(body: LessonActivityPendingBanner()))));
    await tester.pumpAndSettle();
    expect(find.text('학습일 저장 대기'), findsOneWidget);
    expect(find.text('같은 답변 다시 확인'), findsOneWidget);
    expect(h.refreshes, 0);
    await tester.tap(find.text('같은 답변 다시 확인'));
    await tester.pumpAndSettle();
    expect(repository.posts, [request.toJson(), request.toJson()]);
    expect(repository.gets, [request.activityId]);
    expect(find.text('학습일 저장 대기'), findsNothing);
    expect(h.refreshes, 1);
  });

  testWidgets(
      'in-flight pending fits 320px and 200% text without claiming complete',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = ActivityRepositoryFixture()
      ..postGate = Completer<void>();
    final h =
        ActivityHarness(preferences: prefs, activityRepository: repository);
    addTearDown(h.dispose);
    final request = activityDraft();
    await h.store.writeCheckpointAndActivities(activityOwner, activityLesson,
        'checkpoint', request.attemptId, [request]);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: h.container,
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!),
            home: const Scaffold(body: LessonActivityPendingBanner()))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('학습일 저장 대기'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('오늘도 학습했어요'), findsNothing);
    expect(h.refreshes, 0);
    expect(tester.takeException(), isNull);
    repository.postGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('학습일 저장 대기'), findsNothing);
  });
}
