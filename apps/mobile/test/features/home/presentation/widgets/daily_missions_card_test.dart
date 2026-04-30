import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/home/data/models/mission_model.dart';
import 'package:harukoto_mobile/features/home/presentation/widgets/daily_missions_card.dart';
import 'package:lucide_icons/lucide_icons.dart';

void main() {
  group('DailyMissionsCard', () {
    testWidgets('counts isCompleted missions as done and sorts them last',
        (tester) async {
      await _pumpCard(
        tester,
        [
          _mission(
            id: 'done',
            label: '완료 미션',
            isCompleted: true,
            currentCount: 10,
            targetCount: 10,
          ),
          _mission(
            id: 'progress',
            label: '진행 미션',
            currentCount: 1,
            targetCount: 10,
          ),
        ],
      );

      expect(find.text('1/2'), findsOneWidget);

      final progressTop = tester.getTopLeft(find.text('진행 미션'));
      final doneTop = tester.getTopLeft(find.text('완료 미션'));
      expect(progressTop.dy, lessThan(doneTop.dy));
    });

    testWidgets('shows locked visual state for zero target missions',
        (tester) async {
      await _pumpCard(
        tester,
        [
          _mission(
            id: 'locked',
            label: '잠긴 미션',
            targetCount: 0,
          ),
        ],
      );

      expect(find.text('0/1'), findsOneWidget);
      expect(find.text('0/0'), findsNothing);
      expect(find.byIcon(LucideIcons.lock), findsNWidgets(2));
    });
  });
}

Future<void> _pumpCard(
  WidgetTester tester,
  List<MissionModel> missions,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DailyMissionsCard(missions: missions),
        ),
      ),
    ),
  );
}

MissionModel _mission({
  required String id,
  required String label,
  String missionType = 'quiz_daily',
  String description = '',
  int targetCount = 1,
  int currentCount = 0,
  int xpReward = 10,
  bool isCompleted = false,
  bool rewardClaimed = false,
}) {
  return MissionModel(
    id: id,
    missionType: missionType,
    label: label,
    description: description,
    targetCount: targetCount,
    currentCount: currentCount,
    xpReward: xpReward,
    isCompleted: isCompleted,
    rewardClaimed: rewardClaimed,
  );
}
