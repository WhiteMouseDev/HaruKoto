import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/presentation/widgets/result_score_display.dart';

void main() {
  testWidgets(
      'three summary tiles share height and keep XP progress below them',
      (tester) async {
    await _pump(tester, width: 393, correct: 1, total: 1, xp: 10);
    final correct =
        tester.getRect(find.byKey(const ValueKey('result-stat-correct')));
    final xp = tester.getRect(find.byKey(const ValueKey('result-stat-xp')));
    final wrong =
        tester.getRect(find.byKey(const ValueKey('result-stat-wrong')));
    expect(correct.top, xp.top);
    expect(xp.top, wrong.top);
    expect(correct.height, xp.height);
    expect(xp.height, wrong.height);
    expect(tester.getTopLeft(find.byType(LinearProgressIndicator)).dy,
        greaterThan(xp.bottom));
  });

  for (final brightness in Brightness.values) {
    for (final width in [320.0, 393.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('long result values fit $width at ${scale}x in $brightness',
            (tester) async {
          await _pump(tester,
              width: width,
              scale: scale,
              brightness: brightness,
              correct: 100,
              total: 100,
              xp: 10000);
          expect(find.text('100/100'), findsOneWidget);
          expect(find.text('+10000'), findsOneWidget);
          final heights = ['correct', 'xp', 'wrong']
              .map((name) => tester
                  .getSize(find.byKey(ValueKey('result-stat-$name')))
                  .height)
              .toSet();
          expect(heights, hasLength(1));
          expect(tester.takeException(), isNull);
          await tester.drag(
              find.byType(SingleChildScrollView), const Offset(0, -600));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets(
      'reduced motion shows the final score immediately with readable semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, width: 393, reduceMotion: true);
    expect(find.text('100%'), findsOneWidget);
    expect(find.bySemanticsLabel('정답률 100퍼센트'), findsOneWidget);
    expect(find.bySemanticsLabel('정답 10/10'), findsOneWidget);
    expect(find.bySemanticsLabel('획득 XP +100'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
    semantics.dispose();
  });

  testWidgets('zero XP target omits an undefined level progress',
      (tester) async {
    await _pump(tester, width: 393, xpForNext: 0);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'earned XP above the level target never shows negative remaining XP',
      (tester) async {
    await _pump(tester, width: 393, xpForNext: 50);
    expect(find.text('다음 레벨까지 0 XP'), findsOneWidget);
    expect(
        tester
            .widget<LinearProgressIndicator>(
                find.byType(LinearProgressIndicator))
            .value,
        1);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required double width,
  double scale = 1,
  Brightness brightness = Brightness.light,
  int correct = 10,
  int total = 10,
  int xp = 100,
  int xpForNext = 200,
  bool reduceMotion = false,
}) async {
  await tester.binding.setSurfaceSize(Size(width, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(brightness: brightness),
    builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduceMotion),
        child: child!),
    home: Scaffold(
        body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ResultScoreDisplay(
                accuracy: 100,
                correct: correct,
                total: total,
                xpEarned: xp,
                currentXp: 100,
                xpForNext: xpForNext))),
  ));
  if (!reduceMotion) await tester.pumpAndSettle();
}
