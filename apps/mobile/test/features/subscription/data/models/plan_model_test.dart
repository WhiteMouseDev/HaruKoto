import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/subscription/data/models/plan_model.dart';

void main() {
  group('PricingPlan', () {
    test('constant list has 3 plans', () {
      expect(pricingPlans.length, 3);
    });

    test('free plan has correct values', () {
      final free = pricingPlans[0];
      expect(free.id, 'free');
      expect(free.name, '무료');
      expect(free.price, 0);
      expect(free.originalPrice, isNull);
      expect(free.period, '');
      expect(free.recommended, false);
      expect(free.features.isNotEmpty, true);
    });

    test('monthly plan is recommended', () {
      final monthly = pricingPlans[1];
      expect(monthly.id, 'monthly');
      expect(monthly.price, 4900);
      expect(monthly.recommended, true);
      expect(monthly.period, '월');
    });

    test('yearly plan has original price', () {
      final yearly = pricingPlans[2];
      expect(yearly.id, 'yearly');
      expect(yearly.price, 39900);
      expect(yearly.originalPrice, 58800);
      expect(yearly.period, '년');
    });
  });
}
