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

    testWidgets('uses entry dates and semantic study flags for week marks',
        (tester) async {
      await _pumpCard(
        tester,
        weeklyStats: const [
          WeeklyStatEntry(
            date: '2026-05-07',
            wordsStudied: 0,
            xpEarned: 25,
            hasStudied: true,
          ),
        ],
      );

      expect(find.text('목'), findsOneWidget);
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
    });
  });
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
