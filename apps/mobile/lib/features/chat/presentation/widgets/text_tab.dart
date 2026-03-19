import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
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
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            onTap: () {
              HapticService().light();
              onFreeChat();
            },
            child: Container(
              decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.1),
                  AppColors.primary.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            padding: const EdgeInsets.all(AppSizes.md),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('🦊', style: TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '하루와 자유롭게 대화',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '어떤 주제든 일본어로!',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(LucideIcons.messageCircle,
                    size: 20, color: AppColors.primary),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSizes.lg),
        Row(
          children: [
            Icon(LucideIcons.folderOpen,
                size: 16, color: colorScheme.onSurface),
            const SizedBox(width: 6),
            Text(
              '상황별 시나리오',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.sm),
        CategoryGrid(
          onSelect: onSelectCategory,
        ),
        const SizedBox(height: AppSizes.lg),
        Row(
          children: [
            Icon(LucideIcons.clock, size: 16, color: colorScheme.onSurface),
            const SizedBox(width: 6),
            Text(
              '지난 회화 기록',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.sm),
        const ConversationHistoryList(filter: 'text'),
        const SizedBox(height: AppSizes.lg),
      ],
    );
  }
}
