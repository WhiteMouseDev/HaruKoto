import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/haru_typography.dart';

enum CategoryGridVariant { defaultVariant, call, practiceHub }

class _Category {
  final String id;
  final IconData icon;
  final String label;
  final Color color;
  final Color containerColor;
  final String hubIcon;

  const _Category({
    required this.id,
    required this.icon,
    required this.label,
    required this.color,
    required this.containerColor,
    required this.hubIcon,
  });
}

const _categories = [
  _Category(
      id: 'TRAVEL',
      hubIcon: 'assets/icons/figma-conversation-category-travel.svg',
      icon: LucideIcons.plane,
      label: '여행',
      color: AppColors.mintPressed,
      containerColor: AppColors.mintTrack),
  _Category(
      id: 'DAILY',
      hubIcon: 'assets/icons/figma-conversation-category-daily.svg',
      icon: LucideIcons.store,
      label: '일상',
      color: AppColors.streak,
      containerColor: AppColors.streakContainer),
  _Category(
      id: 'BUSINESS',
      hubIcon: 'assets/icons/figma-conversation-category-business.svg',
      icon: LucideIcons.briefcase,
      label: '비즈니스',
      color: AppColors.purple,
      containerColor: AppColors.purpleTrack),
  _Category(
      id: 'FREE',
      hubIcon: 'assets/icons/figma-conversation-category-free.svg',
      icon: LucideIcons.messageSquare,
      label: '자유주제',
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
    if (variant == CategoryGridVariant.practiceHub) {
      return _buildPracticeHub(context);
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;
    final categories = variant == CategoryGridVariant.call
        ? _categories.where((c) => c.id != 'FREE').toList()
        : _categories;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 76 + MediaQuery.textScalerOf(context).scale(32),
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSizes.radiusMd),
            onTap: () => _select(cat.id),
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
                    '시나리오 보기',
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

  Widget _buildPracticeHub(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final light = theme.brightness == Brightness.light;
    final style = OutlinedButton.styleFrom(
      foregroundColor: light ? AppColors.redesignForeground : colors.onSurface,
      side: BorderSide(
        color: light ? AppColors.redesignOutline : colors.outlineVariant,
      ),
      minimumSize: const Size(0, 66),
      visualDensity: VisualDensity.standard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppSizes.gap)),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md, vertical: AppSizes.sm),
      textStyle: HaruTypography.krCompactButton.copyWith(height: 1.5),
    );

    return Column(
      children: [
        for (var row = 0; row < _categories.length; row += 2) ...[
          if (row > 0) const SizedBox(height: AppSizes.sm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final category in _categories.skip(row).take(2)) ...[
                  if (category != _categories[row])
                    const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _select(category.id),
                      style: style,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 34,
                            child: Center(
                              child: ExcludeSemantics(
                                child: SvgPicture.asset(
                                  category.hubIcon,
                                  width: AppSizes.iconLg,
                                  height: AppSizes.iconLg,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSizes.sm),
                          Flexible(child: Text(category.label)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  void _select(String id) {
    HapticService().selection();
    onSelect(id);
  }
}
