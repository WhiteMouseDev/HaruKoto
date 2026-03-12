import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class HomeHeader extends StatelessWidget {
  final String nickname;

  const HomeHeader({super.key, required this.nickname});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'おはよう!',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '안녕, $nickname!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('알림 기능은 준비 중입니다')),
              );
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.bell,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
