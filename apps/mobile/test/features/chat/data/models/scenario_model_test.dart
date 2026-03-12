import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/chat/data/models/scenario_model.dart';

void main() {
  group('ScenarioModel', () {
    test('fromJson parses complete data', () {
      final json = {
        'id': 'scen-1',
        'title': 'Ordering at a restaurant',
        'titleJa': 'レストランで注文する',
        'description': 'Practice ordering food',
        'category': 'restaurant',
        'difficulty': 'beginner',
        'estimatedMinutes': 10,
        'keyExpressions': ['すみません', 'お願いします'],
        'situation': 'You are at a restaurant',
        'yourRole': 'Customer',
        'aiRole': 'Waiter',
      };
      final model = ScenarioModel.fromJson(json);
      expect(model.id, 'scen-1');
      expect(model.title, 'Ordering at a restaurant');
      expect(model.titleJa, 'レストランで注文する');
      expect(model.description, 'Practice ordering food');
      expect(model.category, 'restaurant');
      expect(model.difficulty, 'beginner');
      expect(model.estimatedMinutes, 10);
      expect(model.keyExpressions, ['すみません', 'お願いします']);
      expect(model.situation, 'You are at a restaurant');
      expect(model.yourRole, 'Customer');
      expect(model.aiRole, 'Waiter');
    });

    test('fromJson handles missing fields with defaults', () {
      final json = {'id': 'scen-2'};
      final model = ScenarioModel.fromJson(json);
      expect(model.title, '');
      expect(model.titleJa, '');
      expect(model.description, '');
      expect(model.category, '');
      expect(model.difficulty, '');
      expect(model.estimatedMinutes, 5);
      expect(model.keyExpressions, isEmpty);
      expect(model.situation, '');
      expect(model.yourRole, '');
      expect(model.aiRole, '');
    });
  });
}
