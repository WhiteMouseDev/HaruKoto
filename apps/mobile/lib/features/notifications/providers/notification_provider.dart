import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';
import '../data/notification_repository.dart';
import '../data/models/notification_model.dart';

final notificationRepositoryProvider = Provider((ref) {
  return NotificationRepository(ref.watch(dioProvider));
});

final notificationsProvider =
    FutureProvider.autoDispose<NotificationsResponse>((ref) {
  return ref.watch(notificationRepositoryProvider).fetchNotifications();
});
