import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:harukoto_mobile/features/study/data/models/lesson_models.dart';
import 'package:harukoto_mobile/features/study/domain/lesson_recommendation.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/lesson_continue_banner.dart';
import 'package:harukoto_mobile/features/study/providers/study_map_config.dart';

void main() {
  for (final (status, label, action) in [
    ('IN_PROGRESS', '이어할 레슨', '이어하기'),
    ('NOT_STARTED', '추천 레슨', '시작하기'),
    ('COMPLETED', '다시 볼 레슨', '다시 학습'),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets('$status supports 320px large text in $brightness',
          (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await _pump(tester,
            status: status, brightness: brightness, textScale: 2);
        expect(tester.takeException(), isNull);
        expect(find.text(label), findsOneWidget);
        expect(find.text(action), findsOneWidget);
        expect(find.text('1번 역 · 4번째 레슨'), findsOneWidget);
        expect(find.text('공통점이 반가울 때'), findsOneWidget);
        expect(find.text('10분 · 공감'), findsOneWidget);
        expect(
          tester
              .getSize(find.byKey(const ValueKey('lesson-continue-action')))
              .height,
          greaterThanOrEqualTo(48),
        );
      });
    }
  }

  for (final activation in ['title', 'action', 'screen reader']) {
    testWidgets('$activation opens the same lesson exactly once',
        (tester) async {
      final observer = _PushObserver();
      final semantics = tester.ensureSemantics();
      try {
        await _pump(tester, observer: observer);
        observer.pushCount = 0;

        if (activation == 'screen reader') {
          final node = tester.getSemantics(
              find.byKey(const ValueKey('lesson-continue-semantics')));
          expect(node.label, contains('1번 역 · 4번째 레슨'));
          node.owner!.performAction(node.id, SemanticsAction.tap);
        } else {
          await tester
              .tap(find.text(activation == 'title' ? '공통점이 반가울 때' : '이어하기'));
        }
        await tester.pumpAndSettle();
        expect(find.text('Opened lesson-4'), findsOneWidget);
        expect(observer.pushCount, 1);
      } finally {
        semantics.dispose();
      }
    });
  }
}

Future<void> _pump(
  WidgetTester tester, {
  String status = 'IN_PROGRESS',
  NavigatorObserver? observer,
  Brightness brightness = Brightness.light,
  double textScale = 1,
}) async {
  final lesson = LessonSummaryModel(
    id: 'lesson-4',
    lessonNo: 4,
    chapterLessonNo: 4,
    title: '공통점이 반가울 때',
    topic: '공감',
    estimatedMinutes: 10,
    status: status,
    scoreCorrect: 0,
    scoreTotal: 0,
  );
  final target = RecommendedLessonTarget(
    chapter: ChapterModel(
      id: 'chapter-1',
      jlptLevel: 'N5',
      partNo: 1,
      chapterNo: 1,
      title: '인사와 첫 만남',
      totalLessons: 5,
      completedLessons: status == 'COMPLETED' ? 5 : 3,
      lessons: [lesson],
    ),
    lesson: lesson,
    reason: status == 'COMPLETED' ? '다시 보기 추천' : '이어하기',
  );
  final router = GoRouter(
    observers: [if (observer != null) observer],
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: LessonContinueBanner(target: target),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/study/lessons/:id',
        builder: (context, state) =>
            Scaffold(body: Text('Opened ${state.pathParameters['id']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [studyMapEnabledProvider.overrideWithValue(true)],
    child: MaterialApp.router(
      theme: ThemeData(brightness: brightness),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

class _PushObserver extends NavigatorObserver {
  var pushCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount++;
    super.didPush(route, previousRoute);
  }
}
