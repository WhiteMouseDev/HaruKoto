import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/sizes.dart';
import 'category_grid.dart';
import 'phone_call_banner.dart';
import 'conversation_history_list.dart';

class VoiceTab extends StatelessWidget {
  final ValueChanged<String> onSelectCategory;

  const VoiceTab({super.key, required this.onSelectCategory});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      children: [
        PhoneCallBanner(
          onTap: () {
            context.go('/chat/call/contacts');
          },
        ),
        const SizedBox(height: AppSizes.lg),
        Row(
          children: [
            Icon(LucideIcons.folderOpen,
                size: 16, color: colorScheme.onSurface),
            const SizedBox(width: 6),
            Text(
              '시나리오 통화',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.sm),
        CategoryGrid(
          variant: CategoryGridVariant.call,
          onSelect: onSelectCategory,
        ),
        const SizedBox(height: AppSizes.lg),
        Row(
          children: [
            Icon(LucideIcons.clock, size: 16, color: colorScheme.onSurface),
            const SizedBox(width: 6),
            Text(
              '최근 통화 기록',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.sm),
        const ConversationHistoryList(filter: 'voice'),
        const SizedBox(height: AppSizes.lg),
      ],
    );
  }
}
