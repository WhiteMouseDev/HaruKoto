import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/profile_detail_model.dart';
import '../../data/models/achievement_model.dart';

class AchievementsSection extends StatelessWidget {
  final List<UserAchievement> achievements;

  const AchievementsSection({super.key, required this.achievements});

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final achievedTypes =
        achievements.map((a) => a.achievementType).toSet();
    final achievedCount = achievements.length;
    final totalCount = achievementDefinitions.length;

    final achievedDefs = achievementDefinitions
        .where((d) => achievedTypes.contains(d.type))
        .toList();

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '업적',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () => _showAchievementsSheet(context),
                  child: Row(
                    children: [
                      Text(
                        '$achievedCount/$totalCount 달성',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      Icon(
                        LucideIcons.chevronRight,
                        size: 16,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Progress
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: totalCount > 0 ? achievedCount / totalCount : 0,
                minHeight: 6,
                backgroundColor:
                    theme.colorScheme.onSurface.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
              ),
            ),
            const SizedBox(height: 12),

            // Achievement icons row
            if (achievedDefs.isNotEmpty)
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: achievedDefs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final def = achievedDefs[index];
                    return Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _iconForEmoji(def.emoji),
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    );
                  },
                ),
              )
            else
              Text(
                '첫 번째 업적을 달성해보세요!',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAchievementsSheet(BuildContext context) {
    final theme = Theme.of(context);
    final achievedTypes =
        achievements.map((a) => a.achievementType).toSet();

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
                        '업적',
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
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
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
                                          : theme.colorScheme.onSurface
                                              .withValues(alpha: 0.4),
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
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.3),
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
}
