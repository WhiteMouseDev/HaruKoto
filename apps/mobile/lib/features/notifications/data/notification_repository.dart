import 'package:dio/dio.dart';
import 'models/notification_model.dart';

class NotificationRepository {
  final Dio _dio;

  NotificationRepository(this._dio);

  Future<NotificationsResponse> fetchNotifications({int limit = 20}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/notifications/',
      queryParameters: {'limit': limit},
    );
    return NotificationsResponse.fromJson(response.data!);
  }

  Future<void> markAsRead(String id) async {
    await _dio.patch<Map<String, dynamic>>(
      '/notifications/',
      data: {'id': id},
    );
  }

  Future<void> markAllAsRead() async {
    await _dio.patch<Map<String, dynamic>>('/notifications/');
  }
}
