import 'package:flutter_test/flutter_test.dart';
import 'package:harukoto_mobile/features/notifications/data/models/notification_model.dart';

void main() {
  group('NotificationModel', () {
    test('fromJson parses complete data', () {
      final json = {
        'id': 'n1',
        'type': 'level_up',
        'title': '레벨 업!',
        'body': '레벨 3에 도달했어요',
        'emoji': '🎉',
        'isRead': false,
        'createdAt': '2026-03-13T09:00:00Z',
      };

      final model = NotificationModel.fromJson(json);
      expect(model.id, equals('n1'));
      expect(model.type, equals('level_up'));
      expect(model.title, equals('레벨 업!'));
      expect(model.body, equals('레벨 3에 도달했어요'));
      expect(model.emoji, equals('🎉'));
      expect(model.isRead, isFalse);
      expect(model.createdAt, isA<DateTime>());
    });

    test('fromJson handles missing optional fields', () {
      final json = {
        'id': 'n2',
        'type': 'streak',
        'title': '스트릭',
        'body': '7일 연속!',
        'isRead': true,
        'createdAt': '2026-03-13T09:00:00Z',
      };

      final model = NotificationModel.fromJson(json);
      expect(model.emoji, isNull);
      expect(model.isRead, isTrue);
    });

    test('fromJson handles missing fields with defaults', () {
      final model = NotificationModel.fromJson({});
      expect(model.id, equals(''));
      expect(model.type, equals(''));
      expect(model.title, equals(''));
      expect(model.body, equals(''));
      expect(model.isRead, isTrue);
    });
  });

  group('NotificationsResponse', () {
    test('fromJson parses complete data', () {
      final json = {
        'notifications': [
          {
            'id': 'n1',
            'type': 'level_up',
            'title': '레벨 업!',
            'body': '축하해요',
            'isRead': false,
            'createdAt': '2026-03-13T09:00:00Z',
          },
          {
            'id': 'n2',
            'type': 'streak',
            'title': '스트릭',
            'body': '대단해요',
            'isRead': true,
            'createdAt': '2026-03-12T09:00:00Z',
          },
        ],
        'unreadCount': 1,
      };

      final response = NotificationsResponse.fromJson(json);
      expect(response.notifications, hasLength(2));
      expect(response.unreadCount, equals(1));
      expect(response.notifications[0].id, equals('n1'));
      expect(response.notifications[1].isRead, isTrue);
    });

    test('fromJson handles empty notifications', () {
      final response = NotificationsResponse.fromJson({
        'notifications': [],
        'unreadCount': 0,
      });
      expect(response.notifications, isEmpty);
      expect(response.unreadCount, equals(0));
    });

    test('fromJson handles missing fields', () {
      final response = NotificationsResponse.fromJson({});
      expect(response.notifications, isEmpty);
      expect(response.unreadCount, equals(0));
    });
  });
}
