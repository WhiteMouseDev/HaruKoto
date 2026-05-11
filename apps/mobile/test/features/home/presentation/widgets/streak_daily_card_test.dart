import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/home/data/models/dashboard_model.dart';
import 'package:harukoto_mobile/features/home/presentation/widgets/streak_daily_card.dart';
import 'package:lucide_icons/lucide_icons.dart';

void main() {
  group('StreakDailyCard', () {
    testWidgets('shows needs-action copy before today is studied',
        (tester) async {
      await _pumpCard(
        tester,
        streak: const StreakData(
          current: 1,
          longest: 3,
          studiedToday: false,
          needsActionToday: true,
        ),
        today: _today(hasStudied: false),
      );

      expect(find.text('1일 연속 기록 유지 중'), findsOneWidget);
      expect(find.textContaining('연속 학습 중'), findsNothing);
    });

    testWidgets('shows completed copy after today is studied', (tester) async {
      await _pumpCard(
        tester,
        streak: const StreakData(
          current: 2,
          longest: 3,
          studiedToday: true,
          needsActionToday: false,
        ),
        today: _today(hasStudied: true),
      );

      expect(find.text('2일째 연속 학습 완료!'), findsOneWidget);
    });

    testWidgets('renders the current week from Monday to Sunday',
        (tester) async {
      final currentWeek = _currentWeekDates();

      await _pumpCard(
        tester,
        weeklyStats: [
          WeeklyStatEntry(
            date: _formatDate(currentWeek[6]),
            wordsStudied: 0,
            xpEarned: 25,
            hasStudied: true,
          ),
          WeeklyStatEntry(
            date: _formatDate(currentWeek[0]),
            wordsStudied: 0,
            xpEarned: 25,
            hasStudied: true,
          ),
        ],
      );

      final labels = tester
          .widgetList<Text>(find.byType(Text))
          .map((widget) => widget.data)
          .where((text) => _weekdayLabels.contains(text))
          .toList();

      expect(labels, _weekdayLabels);
      expect(find.byIcon(LucideIcons.check), findsNWidgets(2));
    });

    testWidgets('uses current-week entry dates and semantic study flags',
        (tester) async {
      final currentWeek = _currentWeekDates();

      await _pumpCard(
        tester,
        weeklyStats: [
          WeeklyStatEntry(
            date: _formatDate(currentWeek[3]),
            wordsStudied: 0,
            xpEarned: 25,
            hasStudied: true,
          ),
        ],
      );

      expect(find.text('목'), findsOneWidget);
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
    });

    testWidgets('ignores study marks outside the current week', (tester) async {
      final currentWeek = _currentWeekDates();
      final previousSunday =
          currentWeek.first.subtract(const Duration(days: 1));

      await _pumpCard(
        tester,
        weeklyStats: [
          WeeklyStatEntry(
            date: _formatDate(previousSunday),
            wordsStudied: 0,
            xpEarned: 25,
            hasStudied: true,
          ),
        ],
      );

      expect(find.byIcon(LucideIcons.check), findsNothing);
    });
  });
}

const _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

List<DateTime> _currentWeekDates() {
  final today = _dateOnly(DateTime.now());
  final startOfWeek =
      today.subtract(Duration(days: today.weekday - DateTime.monday));
  return List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String _formatDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

Future<void> _pumpCard(
  WidgetTester tester, {
  StreakData streak = const StreakData(
    current: 0,
    longest: 0,
    studiedToday: false,
    needsActionToday: false,
  ),
  TodayStats? today,
  List<WeeklyStatEntry> weeklyStats = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: StreakDailyCard(
            streak: streak,
            today: today ?? _today(hasStudied: false),
            weeklyStats: weeklyStats,
            dailyGoal: 10,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

TodayStats _today({required bool hasStudied}) {
  return TodayStats(
    wordsStudied: 0,
    quizzesCompleted: 0,
    correctAnswers: 0,
    totalAnswers: 0,
    xpEarned: hasStudied ? 25 : 0,
    goalProgress: 0,
    hasStudied: hasStudied,
  );
}
