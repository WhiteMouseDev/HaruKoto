import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/text_theme.dart';

import '../../../notifications/providers/notification_provider.dart';

String _greetingJp() {
  final hour = DateTime.now().hour;
  if (hour >= 5 && hour < 12) return 'おはよう!';
  if (hour >= 12 && hour < 18) return 'こんにちは!';
  if (hour >= 18) return 'こんばんは!';
  return 'まだ起きてるの?';
}

class HomeTitleBar extends ConsumerWidget {
  const HomeTitleBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final unreadCount = ref.watch(notificationsProvider).whenOrNull(
              data: (data) => data.unreadCount,
            ) ??
        0;

    return Padding(
      padding: const EdgeInsets.only(left: AppSizes.pageHorizontal, right: 10),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                '홈',
                style: TextStyle(
                  fontFamily: redesignFontFamily,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                  letterSpacing: -0.5,
                  color: isLight
                      ? AppColors.redesignForeground
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: unreadCount > 0 ? '알림, 읽지 않은 알림 $unreadCount개' : '알림',
            onPressed: () {
              HapticService().light();
              context.push('/notifications');
            },
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              backgroundColor: AppColors.primaryButton,
              textColor: Colors.white,
              label: ExcludeSemantics(
                child: Text(unreadCount > 9 ? '9+' : '$unreadCount'),
              ),
              child: Image.asset(
                'assets/icons/figma-home-bell.png',
                width: 20.25,
                height: 22.5,
                color: isLight ? null : theme.colorScheme.onSurfaceVariant,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.nickname});

  final String nickname;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    return Padding(
      padding: AppSizes.pageHorizontalEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _greetingJp(),
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: redesignFontFamily,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isLight ? AppColors.brandPink : AppColors.primaryContainer,
              height: 1.4,
              letterSpacing: -0.45,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '$nickname님, 오늘도 힘내볼까요?',
            style: TextStyle(
              fontFamily: redesignFontFamily,
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: isLight
                  ? AppColors.redesignForeground
                  : theme.colorScheme.onSurface,
              height: 1.4,
              letterSpacing: -0.6,
            ),
          ),
        ],
      ),
    );
  }
}
