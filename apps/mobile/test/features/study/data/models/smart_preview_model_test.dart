import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/study/data/models/smart_preview_model.dart';

void main() {
  group('SmartPreviewModel', () {
    test('fromJson parses complete data', () {
      final json = {
        'poolSize': {
          'newReady': 614,
          'reviewDue': 97,
          'retryDue': 5,
        },
        'sessionDistribution': {
          'new': 5,
          'review': 13,
          'retry': 2,
          'total': 20,
        },
        'dailyGoal': 20,
        'todayCompleted': 7,
        'overallProgress': {
          'total': 800,
          'studied': 186,
          'mastered': 42,
          'percentage': 23,
        },
      };

      final model = SmartPreviewModel.fromJson(json);

      expect(model.poolSize.newReady, 614);
      expect(model.poolSize.reviewDue, 97);
      expect(model.poolSize.retryDue, 5);
      expect(model.sessionDistribution.newCount, 5);
      expect(model.sessionDistribution.review, 13);
      expect(model.sessionDistribution.retry, 2);
      expect(model.sessionDistribution.total, 20);
      expect(model.dailyGoal, 20);
      expect(model.todayCompleted, 7);
      expect(model.overallProgress.total, 800);
      expect(model.overallProgress.studied, 186);
      expect(model.overallProgress.mastered, 42);
      expect(model.overallProgress.percentage, 23);
    });

    test('fromJson handles zero values', () {
      final json = {
        'poolSize': {
          'newReady': 0,
          'reviewDue': 0,
          'retryDue': 0,
        },
        'sessionDistribution': {
          'new': 0,
          'review': 0,
          'retry': 0,
          'total': 0,
        },
        'dailyGoal': 20,
        'todayCompleted': 0,
        'overallProgress': {
          'total': 0,
          'studied': 0,
          'mastered': 0,
          'percentage': 0,
        },
      };

      final model = SmartPreviewModel.fromJson(json);

      expect(model.poolSize.newReady, 0);
      expect(model.sessionDistribution.total, 0);
      expect(model.todayCompleted, 0);
      expect(model.overallProgress.percentage, 0);
    });
  });

  group('PoolSize', () {
    test('fromJson parses correctly', () {
      final json = {'newReady': 10, 'reviewDue': 20, 'retryDue': 3};
      final model = PoolSize.fromJson(json);
      expect(model.newReady, 10);
      expect(model.reviewDue, 20);
      expect(model.retryDue, 3);
    });
  });

  group('SessionDistribution', () {
    test('fromJson maps "new" key to newCount', () {
      final json = {'new': 8, 'review': 10, 'retry': 2, 'total': 20};
      final model = SessionDistribution.fromJson(json);
      expect(model.newCount, 8);
      expect(model.review, 10);
      expect(model.retry, 2);
      expect(model.total, 20);
    });
  });

  group('OverallProgress', () {
    test('fromJson parses correctly', () {
      final json = {
        'total': 800,
        'studied': 200,
        'mastered': 50,
        'percentage': 25,
      };
      final model = OverallProgress.fromJson(json);
      expect(model.total, 800);
      expect(model.studied, 200);
      expect(model.mastered, 50);
      expect(model.percentage, 25);
    });
  });
}
