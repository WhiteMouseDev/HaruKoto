import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';
import 'package:harukoto_mobile/features/home/presentation/widgets/weekly_chart.dart';
import 'package:lucide_icons/lucide_icons.dart';

void main() {
  testWidgets('one saved wrong answer fills a bar before quiz completion',
      (tester) async {
    // No completed words or XP: the server includes the saved wrong answer.
    await _pumpChart(tester, [
      _entry('2026-11-02', answered: 1, studied: true),
    ]);

    expect(find.text('이번 주 학습 기록이 아직 없어요'), findsNothing);
    expect(find.text('단어 1개 · XP 0', findRichText: true), findsOneWidget);
    expect(tester.getSize(_bar('2026-11-02')).height, closeTo(5, 0.01));
    expect(_activity('2026-11-02'), findsOneWidget);
    expect(find.byIcon(LucideIcons.check), findsNothing);
    expect(find.text('일별 저장 단어 합계 · 점은 학습한 날'), findsOneWidget);
  });

  testWidgets(
      'non-vocabulary study shows activity without inventing a word bar',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpChart(tester, [
      _entry('2026-10-31', answered: 0),
      _entry('2026-11-01', answered: 0, studied: true),
      _entry('2026-11-02', answered: 0),
    ]);

    expect(find.text('이번 주 학습 기록이 아직 없어요'), findsNothing);
    expect(find.text('단어 0개 · XP 0', findRichText: true), findsOneWidget);
    expect(_activity('2026-11-01'), findsOneWidget);
    expect(_activity('2026-10-31'), findsNothing);
    expect(_activity('2026-11-02'), findsNothing);
    for (final date in ['2026-10-31', '2026-11-01', '2026-11-02']) {
      expect(tester.getSize(_bar(date)).height, 0);
    }
    expect(
        find.bySemanticsLabel('2026-11-01, 학습 기록 있음, 단어 0개'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('known zero uses saved answers instead of completed word count',
      (tester) async {
    await _pumpChart(tester, [
      _entry('2026-11-02', answered: 0, completed: 8, studied: true, xp: 40),
    ]);
    expect(find.text('단어 0개 · XP 40', findRichText: true), findsOneWidget);
    expect(tester.getSize(_bar('2026-11-02')).height, 0);
    expect(_activity('2026-11-02'), findsOneWidget);
    expect(find.textContaining('완료 기준'), findsNothing);
  });

  testWidgets(
      'older and mixed responses clearly retain completed-word fallback',
      (tester) async {
    final oldEntry = WeeklyStatEntry.fromJson({
      'date': '2026-11-01',
      'wordsStudied': 4,
      'xpEarned': 20,
    });
    await _pumpChart(tester, [oldEntry]);
    expect(find.text('단어 4개 · XP 20', findRichText: true), findsOneWidget);
    expect(tester.getSize(_bar('2026-11-01')).height, closeTo(20, 0.01));
    expect(find.text('완료 기준 단어 수 포함 · 점은 학습한 날'), findsOneWidget);

    await _pumpChart(tester, [
      oldEntry,
      _entry('2026-11-02', answered: 1, completed: 9, studied: true),
    ]);
    expect(find.text('단어 5개 · XP 20', findRichText: true), findsOneWidget);
    expect(tester.getSize(_bar('2026-11-02')).height, closeTo(5, 0.01));
    expect(find.text('완료 기준 단어 수 포함 · 점은 학습한 날'), findsOneWidget);
  });

  testWidgets('genuinely empty days show the empty state', (tester) async {
    await _pumpChart(tester, [
      _entry('2026-11-01', answered: 0),
      _entry('2026-11-02', answered: 0),
    ]);
    expect(find.text('이번 주 학습 기록이 아직 없어요'), findsOneWidget);
    expect(find.text('오늘 단어 1개만 학습해도 그래프가 채워져요'), findsOneWidget);
    expect(_bar('2026-11-02'), findsNothing);
    expect(_activity('2026-11-02'), findsNothing);

    await _pumpChart(tester, [_entry('2026-11-02')]);
    expect(find.text('학습을 마치면 완료 기준 기록이 표시돼요'), findsOneWidget);
  });

  testWidgets('word bars and goal use the same scale above and below the goal',
      (tester) async {
    await _pumpChart(tester, [
      _entry('2026-10-31', answered: 1),
      _entry('2026-11-01', answered: 20),
      _entry('2026-11-02', answered: 40),
    ]);
    expect(find.text('목표 20개'), findsOneWidget);
    final small = tester.getRect(_bar('2026-10-31'));
    final goal = tester.getRect(_bar('2026-11-01'));
    final above = tester.getRect(_bar('2026-11-02'));
    final line =
        tester.getTopLeft(find.byKey(const ValueKey('weekly-goal-line')));
    expect(small.height, closeTo(goal.height / 20, 0.01));
    expect(above.height, closeTo(goal.height * 2, 0.01));
    expect(line.dy, closeTo(goal.top, 0.01));
    expect(small.bottom, closeTo(above.bottom, 0.01));
    expect(find.byIcon(LucideIcons.check), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    await _pumpChart(tester, [_entry('2026-11-02', answered: 1)],
        dailyGoal: 100);
    expect(tester.getSize(_bar('2026-11-02')).height, closeTo(1, 0.01));
    expect(find.text('목표 100개'), findsOneWidget);
  });

  testWidgets('saved counts do not create attendance marks or reorder dates',
      (tester) async {
    await _pumpChart(tester, [
      _entry('2026-11-02', answered: 1),
      _entry('2026-10-30', answered: 2),
    ]);
    expect(find.text('이번 주 학습 기록이 아직 없어요'), findsNothing);
    expect(_activity('2026-11-02'), findsNothing);
    expect(_activity('2026-10-30'), findsNothing);
    expect(tester.getTopLeft(_bar('2026-11-02')).dx,
        lessThan(tester.getTopLeft(_bar('2026-10-30')).dx));
  });
}

Finder _bar(String date) => find.byKey(ValueKey('weekly-word-bar-$date'));
Finder _activity(String date) => find.byKey(ValueKey('weekly-activity-$date'));

WeeklyStatEntry _entry(
  String date, {
  int? answered,
  int completed = 0,
  bool studied = false,
  int xp = 0,
}) =>
    WeeklyStatEntry(
      date: date,
      wordsStudied: completed,
      xpEarned: xp,
      hasStudied: studied,
      vocabularyAnsweredCount: answered,
    );

Future<void> _pumpChart(
  WidgetTester tester,
  List<WeeklyStatEntry> entries, {
  int dailyGoal = 20,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: WeeklyChart(weeklyStats: entries, dailyGoal: dailyGoal),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}
