import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/my/data/models/achievement_model.dart';

void main() {
  group('AchievementDefinition', () {
    test('constant list has expected entries', () {
      expect(achievementDefinitions.isNotEmpty, true);
      expect(achievementDefinitions.length, 20);
    });

    test('first entry is first_quiz', () {
      final first = achievementDefinitions[0];
      expect(first.type, 'first_quiz');
      expect(first.title, '첫 퀴즈');
      expect(first.emoji, 'target');
      expect(first.category, 'quiz');
    });

    test('contains streak achievements', () {
      final streakAchievements =
          achievementDefinitions.where((a) => a.category == 'streak').toList();
      expect(streakAchievements.length, 4);
    });
  });
}
