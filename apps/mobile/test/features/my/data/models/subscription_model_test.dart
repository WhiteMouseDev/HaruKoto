import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/my/data/models/subscription_model.dart';

void main() {
  group('SubscriptionInfo', () {
    test('fromJson parses complete data', () {
      final json = {
        'isPremium': true,
        'plan': 'monthly',
        'expiresAt': '2025-01-15T00:00:00Z',
        'cancelledAt': null,
      };
      final model = SubscriptionInfo.fromJson(json);
      expect(model.isPremium, true);
      expect(model.plan, 'monthly');
      expect(model.expiresAt, '2025-01-15T00:00:00Z');
      expect(model.cancelledAt, isNull);
    });

    test('fromJson handles missing fields with defaults', () {
      final model = SubscriptionInfo.fromJson({});
      expect(model.isPremium, false);
      expect(model.plan, 'free');
      expect(model.expiresAt, isNull);
      expect(model.cancelledAt, isNull);
    });

    test('isCancelled getter returns true when cancelledAt is set', () {
      final model = SubscriptionInfo.fromJson({
        'cancelledAt': '2024-12-01T00:00:00Z',
      });
      expect(model.isCancelled, true);
    });

    test('isCancelled getter returns false when cancelledAt is null', () {
      final model = SubscriptionInfo.fromJson({});
      expect(model.isCancelled, false);
    });
  });

  group('AiUsage', () {
    test('fromJson parses complete data', () {
      final json = {
        'chatCount': 2,
        'chatLimit': 5,
        'callCount': 1,
        'callLimit': 3,
      };
      final model = AiUsage.fromJson(json);
      expect(model.chatCount, 2);
      expect(model.chatLimit, 5);
      expect(model.callCount, 1);
      expect(model.callLimit, 3);
    });

    test('fromJson handles missing fields with defaults', () {
      final model = AiUsage.fromJson({});
      expect(model.chatCount, 0);
      expect(model.chatLimit, 3);
      expect(model.callCount, 0);
      expect(model.callLimit, 1);
    });
  });

  group('SubscriptionStatus', () {
    test('fromJson parses flat backend response', () {
      final json = {
        'isPremium': true,
        'plan': 'yearly',
        'expiresAt': '2026-01-01T00:00:00Z',
        'cancelledAt': null,
        'usage': {
          'chatCount': 10,
          'chatSeconds': 999,
          'callCount': 5,
          'callSeconds': 999,
        },
      };
      final model = SubscriptionStatus.fromJson(json);
      expect(model.subscription.isPremium, true);
      expect(model.subscription.plan, 'yearly');
      expect(model.aiUsage, isNotNull);
      expect(model.aiUsage!.chatCount, 10);
    });

    test('fromJson handles missing fields', () {
      final model = SubscriptionStatus.fromJson({});
      expect(model.subscription.isPremium, false);
      expect(model.subscription.plan, 'free');
      expect(model.aiUsage, isNull);
    });
  });
}
