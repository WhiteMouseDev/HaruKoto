import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/stats/data/models/level_progress_model.dart';

void main() {
  group('ProgressCategory', () {
    test('fromJson parses complete data', () {
      final json = {'total': 100, 'mastered': 40, 'inProgress': 30};
      final model = ProgressCategory.fromJson(json);
      expect(model.total, 100);
      expect(model.mastered, 40);
      expect(model.inProgress, 30);
    });

    test('fromJson handles missing fields with defaults', () {
      final model = ProgressCategory.fromJson({});
      expect(model.total, 0);
      expect(model.mastered, 0);
      expect(model.inProgress, 0);
    });
  });

  group('LevelProgressData', () {
    test('fromJson parses complete data with nested models', () {
      final json = {
        'vocabulary': {'total': 200, 'mastered': 80, 'inProgress': 50},
        'grammar': {'total': 100, 'mastered': 30, 'inProgress': 20},
      };
      final model = LevelProgressData.fromJson(json);
      expect(model.vocabulary.total, 200);
      expect(model.vocabulary.mastered, 80);
      expect(model.vocabulary.inProgress, 50);
      expect(model.grammar.total, 100);
      expect(model.grammar.mastered, 30);
      expect(model.grammar.inProgress, 20);
    });

    test('fromJson handles missing nested objects with defaults', () {
      final model = LevelProgressData.fromJson({});
      expect(model.vocabulary.total, 0);
      expect(model.vocabulary.mastered, 0);
      expect(model.grammar.total, 0);
      expect(model.grammar.mastered, 0);
    });
  });
}
