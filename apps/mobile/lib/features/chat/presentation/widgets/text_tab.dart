import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/haru_typography.dart';
import 'category_grid.dart';
import 'conversation_history_list.dart';

class TextTab extends StatelessWidget {
  final Widget? journeyCard;
  final VoidCallback onFreeChat;
  final ValueChanged<String> onSelectCategory;

  const TextTab({
    super.key,
    this.journeyCard,
    required this.onFreeChat,
    required this.onSelectCategory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    final foreground = light ? AppColors.redesignForeground : colors.onSurface;

    return ListView(
      padding: AppSizes.pageHorizontalEdge,
      children: [
        if (journeyCard != null) journeyCard!,
        Semantics(
          header: true,
          child: Text(
            '상황별 회화 연습',
            style: HaruTypography.krTitle3.copyWith(
              fontSize: 16,
              letterSpacing: -0.4,
              color: foreground,
            ),
          ),
        ),
        const SizedBox(height: AppSizes.gap),
        CategoryGrid(
          onSelect: onSelectCategory,
          variant: CategoryGridVariant.practiceHub,
        ),
        const SizedBox(height: AppSizes.gap),
        FilledButton(
          key: const ValueKey('conversation-text-practice-banner'),
          style: FilledButton.styleFrom(
            backgroundColor:
                light ? AppColors.redesignSurface : colors.surfaceContainerHigh,
            foregroundColor: foreground,
            minimumSize: const Size(double.infinity, 67),
            visualDensity: VisualDensity.standard,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md,
              vertical: AppSizes.gap,
            ),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(AppSizes.gap)),
            ),
            textStyle: HaruTypography.krCompactButton.copyWith(height: 1.5),
          ),
          onPressed: () {
            HapticService().light();
            onFreeChat();
          },
          child: Column(
            children: [
              const Text('대화가 부담스럽다면?', textAlign: TextAlign.center),
              const SizedBox(height: 2),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      '글로 자유롭게 연습하기',
                      textAlign: TextAlign.center,
                      style: HaruTypography.krBody3.copyWith(
                        fontWeight: FontWeight.w500,
                        color: light
                            ? const Color(0xFF505050)
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    LucideIcons.chevronRight,
                    size: AppSizes.iconSm,
                    color: light ? AppColors.redesignStrong : foreground,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.xl),
        Row(
          children: [
            Icon(LucideIcons.clock, size: 16, color: colors.onSurface),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '최근 연습 기록',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
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
