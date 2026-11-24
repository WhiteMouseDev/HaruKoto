import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';
import 'package:harukoto_mobile/features/stats/data/models/study_overview_model.dart';
import 'package:harukoto_mobile/features/stats/presentation/widgets/stats_bar_chart.dart';
import 'package:harukoto_mobile/features/stats/presentation/widgets/study_tab.dart';
import 'package:harukoto_mobile/features/stats/providers/stats_provider.dart';

void main() {
  testWidgets('shows lifetime summary and three rolling question categories',
      (tester) async {
    await _pump(tester, () async => _overview());

    expect(find.text('누적 학습 요약'), findsOneWidget);
    expect(find.text('4회'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('20개'), findsOneWidget);
    expect(find.text('10개'), findsOneWidget);
    expect(find.text('5개'), findsOneWidget);
    expect(find.text('57%'), findsOneWidget);
    expect(find.text('29%'), findsOneWidget);
    expect(find.text('14%'), findsOneWidget);

    final chart = tester.widget<StatsBarChart>(find.byType(StatsBarChart));
    expect(chart.dateRangeLabel, '10.29~11.4');
    expect(chart.days.length, 7);
    expect(chart.days.last.label, '11/4');
    expect(chart.days.last.counts?.sentences, 5);
    expect(find.text('총 대화 수'), findsOneWidget);
    expect(find.text('7회'), findsOneWidget);
    expect(find.text('총 학습'), findsNothing);
    expect(find.text('대화 시간'), findsNothing);
  });

  testWidgets('reports that there are no questions, with no accuracy value',
      (tester) async {
    await _pump(tester, () async => _overview(empty: true));

    expect(find.text('최근 7일간 문제풀이 기록이 없어요'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('0개'), findsNWidgets(3));
    expect(find.text('0%'), findsNWidgets(3));
    expect(find.text('대화 시간'), findsNothing);
  });

  testWidgets('allows retry without presenting a request error as zero data',
      (tester) async {
    var requests = 0;
    await _pump(tester, () async {
      requests++;
      if (requests == 1) throw const FormatException('invalid overview');
      return _overview();
    });

    expect(find.text('학습별 통계를 불러오지 못했어요'), findsOneWidget);
    expect(find.text('최근 7일간 문제풀이 기록이 없어요'), findsNothing);

    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();

    expect(requests, 2);
    expect(find.text('누적 학습 요약'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester,
  Future<StudyOverview> Function() load,
) async {
  await tester.pumpWidget(ProviderScope(
    retry: (_, __) => null,
    overrides: [studyOverviewProvider.overrideWith((ref) => load())],
    child: const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: StudyTab()),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

StudyOverview _overview({bool empty = false}) {
  return StudyOverview(
    quizzesCompleted: empty ? 0 : 4,
    correctAnswers: empty ? 0 : 3,
    totalAnswers: empty ? 0 : 4,
    conversationCount: empty ? 0 : 7,
    daily: [
      for (var index = 0; index < 7; index++)
        WeeklyQuestionStatEntry(
          date: DateTime.utc(2026, 10, 29 + index)
              .toIso8601String()
              .substring(0, 10),
          hasStudied: !empty && index == 6,
          vocabularyAnsweredCount: !empty && index == 6 ? 20 : 0,
          grammarAnsweredCount: !empty && index == 6 ? 10 : 0,
          sentenceArrangeAnsweredCount: !empty && index == 6 ? 5 : 0,
        ),
    ],
  );
}
