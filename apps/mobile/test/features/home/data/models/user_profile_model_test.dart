import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/home/data/models/user_profile_model.dart';

void main() {
  group('UserProfileModel', () {
    test('fromJson parses complete data', () {
      final json = {
        'nickname': 'TestUser',
        'dailyGoal': 20,
        'showKana': false,
        'jlptLevel': 'N3',
        'avatarUrl': 'https://example.com/avatar.png',
      };
      final model = UserProfileModel.fromJson(json);
      expect(model.nickname, 'TestUser');
      expect(model.dailyGoal, 20);
      expect(model.showKana, false);
      expect(model.jlptLevel, 'N3');
      expect(model.avatarUrl, 'https://example.com/avatar.png');
    });

    test('fromJson handles missing fields with defaults', () {
      final model = UserProfileModel.fromJson({});
      expect(model.nickname, '학습자');
      expect(model.dailyGoal, 10);
      expect(model.showKana, true);
      expect(model.jlptLevel, 'N5');
      expect(model.avatarUrl, isNull);
    });
  });
}
