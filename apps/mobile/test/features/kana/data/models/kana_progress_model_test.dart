import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/kana/data/models/kana_progress_model.dart';

void main() {
  group('KanaTypeProgress', () {
    test('fromJson parses complete data', () {
      final json = {'learned': 30, 'mastered': 20, 'total': 46, 'pct': 65};
      final model = KanaTypeProgress.fromJson(json);
      expect(model.learned, 30);
      expect(model.mastered, 20);
      expect(model.total, 46);
      expect(model.pct, 65);
    });

    test('fromJson handles missing fields with defaults', () {
      final model = KanaTypeProgress.fromJson({});
      expect(model.learned, 0);
      expect(model.mastered, 0);
      expect(model.total, 0);
      expect(model.pct, 0);
    });
  });

  group('KanaProgressModel', () {
    test('fromJson parses complete data with nested models', () {
      final json = {
        'hiragana': {'learned': 46, 'mastered': 40, 'total': 46, 'pct': 100},
        'katakana': {'learned': 20, 'mastered': 10, 'total': 46, 'pct': 43},
      };
      final model = KanaProgressModel.fromJson(json);
      expect(model.hiragana.learned, 46);
      expect(model.hiragana.pct, 100);
      expect(model.katakana.learned, 20);
      expect(model.katakana.pct, 43);
    });
  });
}
