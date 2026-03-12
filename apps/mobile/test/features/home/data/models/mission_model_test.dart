import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/home/data/models/mission_model.dart';

void main() {
  group('MissionModel', () {
    test('fromJson parses complete data', () {
      final json = {
        'id': 'mission-1',
        'missionType': 'quiz_3',
        'targetCount': 3,
        'currentCount': 1,
        'xpReward': 50,
        'isCompleted': false,
        'rewardClaimed': false,
      };
      final model = MissionModel.fromJson(json);
      expect(model.id, 'mission-1');
      expect(model.missionType, 'quiz_3');
      expect(model.targetCount, 3);
      expect(model.currentCount, 1);
      expect(model.xpReward, 50);
      expect(model.isCompleted, false);
      expect(model.rewardClaimed, false);
    });

    test('fromJson handles missing fields with defaults', () {
      final model = MissionModel.fromJson({});
      expect(model.id, '');
      expect(model.missionType, 'words');
      expect(model.targetCount, 0);
      expect(model.currentCount, 0);
      expect(model.xpReward, 0);
      expect(model.isCompleted, false);
      expect(model.rewardClaimed, false);
    });

    test('progress getter computes correctly', () {
      final model = MissionModel.fromJson({
        'targetCount': 10,
        'currentCount': 7,
      });
      expect(model.progress, 0.7);
    });

    test('progress clamps to 1.0 when exceeded', () {
      final model = MissionModel.fromJson({
        'targetCount': 5,
        'currentCount': 8,
      });
      expect(model.progress, 1.0);
    });

    test('progress returns 0.0 when targetCount is 0', () {
      final model = MissionModel.fromJson({'targetCount': 0});
      expect(model.progress, 0.0);
    });

    test('label getter returns correct labels', () {
      expect(
        MissionModel.fromJson({'missionType': 'words_5'}).label,
        '단어 5개 학습',
      );
      expect(
        MissionModel.fromJson({'missionType': 'quiz_1'}).label,
        '퀴즈 1회 완료',
      );
      expect(
        MissionModel.fromJson({'missionType': 'correct_10'}).label,
        '정답 10개 달성',
      );
      expect(
        MissionModel.fromJson({'missionType': 'chat_1'}).label,
        '회화 1회 완료',
      );
      expect(
        MissionModel.fromJson({'missionType': 'kana_learn_5'}).label,
        '가나 5자 학습',
      );
    });

    test('label getter returns missionType for unknown types', () {
      final model = MissionModel.fromJson({'missionType': 'unknown_type'});
      expect(model.label, 'unknown_type');
    });
  });
}
