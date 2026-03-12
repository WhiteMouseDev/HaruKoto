import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/subscription/data/models/payment_model.dart';

void main() {
  group('PaymentRecord', () {
    test('fromJson parses complete data', () {
      final json = {
        'id': 'pay-1',
        'plan': 'monthly',
        'amount': 4900,
        'status': 'completed',
        'paidAt': '2024-01-15T10:00:00Z',
        'createdAt': '2024-01-15T09:55:00Z',
      };
      final model = PaymentRecord.fromJson(json);
      expect(model.id, 'pay-1');
      expect(model.plan, 'monthly');
      expect(model.amount, 4900);
      expect(model.status, 'completed');
      expect(model.paidAt, '2024-01-15T10:00:00Z');
      expect(model.createdAt, '2024-01-15T09:55:00Z');
    });

    test('fromJson handles missing fields with defaults', () {
      final model = PaymentRecord.fromJson({});
      expect(model.id, '');
      expect(model.plan, '');
      expect(model.amount, 0);
      expect(model.status, '');
      expect(model.paidAt, isNull);
      expect(model.createdAt, '');
    });
  });
}
