import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/services/haptic_service.dart';

import '../../../notifications/providers/notification_provider.dart';

String _greetingJp() {
  final hour = DateTime.now().hour;
  if (hour >= 5 && hour < 12) return 'おはよう!';
  if (hour >= 12 && hour < 18) return 'こんにちは!';
  if (hour >= 18) return 'こんばんは!';
  return 'まだ起きてるの?';
}

String _greetingKr(String nickname) {
  final hour = DateTime.now().hour;
  if (hour >= 5 && hour < 12) return '오늘도 화이팅, $nickname!';
  if (hour >= 12 && hour < 18) return '점심은 먹었어, $nickname?';
  if (hour >= 18) return '오늘 하루 수고했어, $nickname!';
  return '야행성이구나, $nickname!';
}

class HomeHeader extends ConsumerWidget {
  final String nickname;

  const HomeHeader({super.key, required this.nickname});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unreadCount = ref.watch(notificationsProvider).whenOrNull(
              data: (data) => data.unreadCount,
            ) ??
        0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greetingJp(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _greetingKr(nickname),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticService().light();
                context.push('/notifications');
              },
              customBorder: const CircleBorder(),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.bell,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Center(
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
