import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/sizes.dart';
import '../../../my/data/models/achievement_model.dart';
import '../../../my/data/models/profile_detail_model.dart';
import '../../../my/providers/my_provider.dart';

class ShortcutGrid extends ConsumerWidget {
  const ShortcutGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final shortcuts = [
      _ShortcutItem(
        icon: LucideIcons.bookMarked,
        label: '단어장',
        onTap: () => context.push('/study/wordbook'),
      ),
      _ShortcutItem(
        icon: LucideIcons.fileX,
        label: '오답노트',
        onTap: () => context.push('/study/wrong-answers'),
      ),
      _ShortcutItem(
        icon: LucideIcons.trophy,
        label: '도전과제',
        onTap: () => _showAchievements(context, ref),
      ),
      _ShortcutItem(
        icon: LucideIcons.grid,
        label: '가나 차트',
        onTap: () => context.push('/study/kana/chart'),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.pageHorizontal),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: shortcuts.map((item) {
              return Expanded(
                child: GestureDetector(
                  onTap: item.onTap,
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          item.icon,
                          size: 24,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showAchievements(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.read(profileDetailProvider);
    final achievements = profileAsync.hasValue
        ? profileAsync.value!.achievements
        : <UserAchievement>[];

    final theme = Theme.of(context);
    final achievedTypes = achievements.map((a) => a.achievementType).toSet();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '도전과제',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${achievements.length}/${achievementDefinitions.length} 달성',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.85,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemCount: achievementDefinitions.length,
                    itemBuilder: (context, index) {
                      final def = achievementDefinitions[index];
                      final isAchieved = achievedTypes.contains(def.type);

                      return Opacity(
                        opacity: isAchieved ? 1.0 : 0.4,
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _iconForEmoji(def.emoji),
                                      size: 28,
                                      color: isAchieved
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      def.title,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isAchieved)
                                Positioned(
                                  right: 6,
                                  top: 6,
                                  child: Icon(
                                    LucideIcons.lock,
                                    size: 12,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  IconData _iconForEmoji(String emoji) {
    switch (emoji) {
      case 'target':
        return LucideIcons.target;
      case 'trophy':
        return LucideIcons.trophy;
      case 'star':
        return LucideIcons.star;
      case 'messageCircle':
        return LucideIcons.messageCircle;
      case 'flame':
        return LucideIcons.flame;
      case 'bookOpen':
        return LucideIcons.bookOpen;
      case 'zap':
        return LucideIcons.zap;
      default:
        return LucideIcons.award;
    }
  }
}

class _ShortcutItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ShortcutItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}
