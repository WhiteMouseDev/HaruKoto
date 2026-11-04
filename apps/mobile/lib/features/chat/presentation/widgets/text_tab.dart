import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/services/haptic_service.dart';
import 'category_grid.dart';
import 'conversation_history_list.dart';

class TextTab extends StatelessWidget {
  final VoidCallback onFreeChat;
  final ValueChanged<String> onSelectCategory;

  const TextTab({
    super.key,
    required this.onFreeChat,
    required this.onSelectCategory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
      children: [
        Row(
          children: [
            Icon(LucideIcons.folderOpen,
                size: 16, color: colorScheme.onSurface),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '상황을 고르고 말하기로 연습',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.sm),
        CategoryGrid(
          onSelect: onSelectCategory,
        ),
        const SizedBox(height: AppSizes.xs),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onSurfaceVariant,
              minimumSize: const Size(0, AppSizes.buttonHeight),
            ),
            onPressed: () {
              HapticService().light();
              onFreeChat();
            },
            icon: const Icon(LucideIcons.messageCircle, size: AppSizes.iconSm),
            label: const Text('글로 자유롭게 연습'),
          ),
        ),
        const SizedBox(height: AppSizes.lg),
        Row(
          children: [
            Icon(LucideIcons.clock, size: 16, color: colorScheme.onSurface),
            const SizedBox(width: 6),
            Text(
              '최근 연습 기록',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.sm),
        const ConversationHistoryList(filter: 'practice'),
        const SizedBox(height: AppSizes.lg),
      ],
    );
  }
}
