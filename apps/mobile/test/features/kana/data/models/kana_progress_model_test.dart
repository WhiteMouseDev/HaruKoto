import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/kana/data/models/kana_progress_model.dart';

void main() {
  group('KanaTypeProgress', () {
    test('fromJson parses complete data', () {
      final json = {'learned': 30, 'mastered': 20, 'total': 46};
      final model = KanaTypeProgress.fromJson(json);
      expect(model.learned, 30);
      expect(model.mastered, 20);
      expect(model.total, 46);
      // pct is computed: mastered * 100 ~/ total = 20 * 100 ~/ 46 = 43
      expect(model.pct, 43);
    });

    test('fromJson handles missing fields with defaults', () {
      final model = KanaTypeProgress.fromJson({});
      expect(model.learned, 0);
      expect(model.mastered, 0);
      expect(model.total, 0);
      expect(model.pct, 0);
    });

    test('completed returns true when all mastered', () {
      final model = KanaTypeProgress.fromJson(
          {'learned': 46, 'mastered': 46, 'total': 46});
      expect(model.completed, true);
      expect(model.pct, 100);
    });
  });

  group('KanaProgressModel', () {
    test('fromJson parses complete data with nested models', () {
      final json = {
        'hiragana': {'learned': 46, 'mastered': 46, 'total': 46},
        'katakana': {'learned': 20, 'mastered': 10, 'total': 46},
      };
      final model = KanaProgressModel.fromJson(json);
      expect(model.hiragana.learned, 46);
      expect(model.hiragana.pct, 100);
      expect(model.katakana.learned, 20);
      // 10 * 100 ~/ 46 = 21
      expect(model.katakana.pct, 21);
    });
  });
}
