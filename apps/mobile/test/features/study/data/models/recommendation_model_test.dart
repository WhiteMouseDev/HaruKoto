import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/recommendation_model.dart';

void main() {
  group('RecommendationModel', () {
    test('fromJson parses complete data', () {
      final json = {
        'reviewDueCount': 15,
        'newWordsCount': 10,
        'wrongCount': 5,
        'lastReviewedAt': '2024-01-15T10:00:00Z',
      };
      final model = RecommendationModel.fromJson(json);
      expect(model.reviewDueCount, 15);
      expect(model.newWordsCount, 10);
      expect(model.wrongCount, 5);
      expect(model.lastReviewedAt, '2024-01-15T10:00:00Z');
    });

    test('fromJson handles missing fields with defaults', () {
      final model = RecommendationModel.fromJson({});
      expect(model.reviewDueCount, 0);
      expect(model.newWordsCount, 0);
      expect(model.wrongCount, 0);
      expect(model.lastReviewedAt, isNull);
    });

    test('lastReviewText returns null when lastReviewedAt is null', () {
      final model = RecommendationModel.fromJson({});
      expect(model.lastReviewText, isNull);
    });
  });
}
