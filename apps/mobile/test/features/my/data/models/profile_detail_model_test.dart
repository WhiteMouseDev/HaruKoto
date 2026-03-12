import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/my/data/models/profile_detail_model.dart';

void main() {
  group('LevelProgress', () {
    test('fromJson parses complete data', () {
      final json = {'currentXp': 500, 'xpForNext': 1000};
      final model = LevelProgress.fromJson(json);
      expect(model.currentXp, 500);
      expect(model.xpForNext, 1000);
    });

    test('fromJson handles missing fields with defaults', () {
      final model = LevelProgress.fromJson({});
      expect(model.currentXp, 0);
      expect(model.xpForNext, 1000);
    });
  });

  group('ProfileInfo', () {
    test('fromJson parses complete data', () {
      final json = {
        'id': 'user-1',
        'nickname': 'TestUser',
        'avatarUrl': 'https://example.com/avatar.png',
        'jlptLevel': 'N3',
        'dailyGoal': 20,
        'experiencePoints': 5000,
        'level': 10,
        'levelProgress': {'currentXp': 500, 'xpForNext': 1000},
        'streakCount': 15,
        'longestStreak': 30,
        'showKana': true,
        'createdAt': '2024-01-01T00:00:00Z',
      };
      final model = ProfileInfo.fromJson(json);
      expect(model.id, 'user-1');
      expect(model.nickname, 'TestUser');
      expect(model.avatarUrl, 'https://example.com/avatar.png');
      expect(model.jlptLevel, 'N3');
      expect(model.dailyGoal, 20);
      expect(model.experiencePoints, 5000);
      expect(model.level, 10);
      expect(model.levelProgress.currentXp, 500);
      expect(model.streakCount, 15);
      expect(model.longestStreak, 30);
      expect(model.showKana, true);
      expect(model.createdAt, '2024-01-01T00:00:00Z');
    });

    test('fromJson handles missing fields with defaults', () {
      final model = ProfileInfo.fromJson({});
      expect(model.id, '');
      expect(model.nickname, '');
      expect(model.avatarUrl, isNull);
      expect(model.jlptLevel, 'N5');
      expect(model.dailyGoal, 10);
      expect(model.experiencePoints, 0);
      expect(model.level, 1);
      expect(model.levelProgress.currentXp, 0);
      expect(model.levelProgress.xpForNext, 1000);
      expect(model.streakCount, 0);
      expect(model.longestStreak, 0);
      expect(model.showKana, false);
      expect(model.createdAt, '');
    });
  });

  group('ProfileSummary', () {
    test('fromJson parses complete data', () {
      final json = {
        'totalWordsStudied': 500,
        'totalQuizzesCompleted': 100,
        'totalStudyDays': 60,
        'totalXpEarned': 10000,
      };
      final model = ProfileSummary.fromJson(json);
      expect(model.totalWordsStudied, 500);
      expect(model.totalQuizzesCompleted, 100);
      expect(model.totalStudyDays, 60);
      expect(model.totalXpEarned, 10000);
    });

    test('fromJson handles missing fields with defaults', () {
      final model = ProfileSummary.fromJson({});
      expect(model.totalWordsStudied, 0);
      expect(model.totalQuizzesCompleted, 0);
      expect(model.totalStudyDays, 0);
      expect(model.totalXpEarned, 0);
    });
  });

  group('UserAchievement', () {
    test('fromJson parses complete data', () {
      final json = {
        'achievementType': 'streak_7',
        'achievedAt': '2024-01-15T10:00:00Z',
      };
      final model = UserAchievement.fromJson(json);
      expect(model.achievementType, 'streak_7');
      expect(model.achievedAt, '2024-01-15T10:00:00Z');
    });

    test('fromJson handles missing fields with defaults', () {
      final model = UserAchievement.fromJson({});
      expect(model.achievementType, '');
      expect(model.achievedAt, '');
    });
  });

  group('ProfileDetailModel', () {
    test('fromJson parses complete data with nested models', () {
      final json = {
        'profile': {
          'id': 'user-1',
          'nickname': 'Test',
          'jlptLevel': 'N4',
          'dailyGoal': 15,
          'experiencePoints': 3000,
          'level': 5,
          'levelProgress': {'currentXp': 200, 'xpForNext': 500},
          'streakCount': 10,
          'longestStreak': 20,
          'showKana': true,
          'createdAt': '2024-01-01T00:00:00Z',
        },
        'summary': {
          'totalWordsStudied': 200,
          'totalQuizzesCompleted': 50,
          'totalStudyDays': 30,
          'totalXpEarned': 3000,
        },
        'achievements': [
          {
            'achievementType': 'first_quiz',
            'achievedAt': '2024-01-02T00:00:00Z',
          },
        ],
      };
      final model = ProfileDetailModel.fromJson(json);
      expect(model.profile.id, 'user-1');
      expect(model.profile.nickname, 'Test');
      expect(model.summary.totalWordsStudied, 200);
      expect(model.achievements.length, 1);
      expect(model.achievements[0].achievementType, 'first_quiz');
    });

    test('fromJson handles missing nested objects with defaults', () {
      final model = ProfileDetailModel.fromJson({});
      expect(model.profile.id, '');
      expect(model.summary.totalWordsStudied, 0);
      expect(model.achievements, isEmpty);
    });
  });
}
