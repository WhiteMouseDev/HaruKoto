import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/services/haptic_service.dart';

enum CategoryGridVariant { defaultVariant, call }

class _Category {
  final String id;
  final IconData icon;
  final String label;
  final String scenarioCount;
  final Color color;
  final Color containerColor;

  const _Category({
    required this.id,
    required this.icon,
    required this.label,
    required this.scenarioCount,
    required this.color,
    required this.containerColor,
  });
}

const _categories = [
  _Category(
      id: 'TRAVEL',
      icon: LucideIcons.plane,
      label: '여행',
      scenarioCount: '12 시나리오',
      color: AppColors.mintPressed,
      containerColor: AppColors.mintTrack),
  _Category(
      id: 'DAILY',
      icon: LucideIcons.store,
      label: '일상',
      scenarioCount: '10 시나리오',
      color: AppColors.streak,
      containerColor: AppColors.streakContainer),
  _Category(
      id: 'BUSINESS',
      icon: LucideIcons.briefcase,
      label: '비즈니스',
      scenarioCount: '8 시나리오',
      color: AppColors.purple,
      containerColor: AppColors.purpleTrack),
  _Category(
      id: 'FREE',
      icon: LucideIcons.messageSquare,
      label: '자유주제',
      scenarioCount: '무제한',
      color: AppColors.sakura,
      containerColor: AppColors.sakuraTrack),
];

class CategoryGrid extends StatelessWidget {
  final ValueChanged<String> onSelect;
  final CategoryGridVariant variant;

  const CategoryGrid({
    super.key,
    required this.onSelect,
    this.variant = CategoryGridVariant.defaultVariant,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final categories = variant == CategoryGridVariant.call
        ? _categories.where((c) => c.id != 'FREE').toList()
        : _categories;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            onTap: () {
              HapticService().selection();
              onSelect(cat.id);
            },
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                border: Border.all(color: Colors.transparent),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isLight
                          ? cat.containerColor
                          : cat.color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(cat.icon, size: 24, color: cat.color),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    cat.label,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cat.scenarioCount,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
