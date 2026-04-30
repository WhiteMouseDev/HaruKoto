import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../data/models/profile_detail_model.dart';

class ProfileHero extends StatelessWidget {
  final ProfileInfo profile;
  final ProfileSummary summary;
  final VoidCallback? onEditNickname;

  const ProfileHero({
    super.key,
    required this.profile,
    required this.summary,
    this.onEditNickname,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    final stats = [
      (
        LucideIcons.calendar,
        '총 학습일',
        '${summary.totalStudyDays}일',
        AppColors.mintPressed
      ),
      (
        LucideIcons.bookOpen,
        '학습 단어',
        '${summary.totalWordsStudied}개',
        AppColors.sakura
      ),
      (
        LucideIcons.zap,
        '총 XP',
        '${profile.experiencePoints}',
        AppColors.purple
      ),
      (
        LucideIcons.flame,
        '최장 연속',
        '${profile.longestStreak}일',
        AppColors.streak
      ),
    ];

    final xpProgress = profile.levelProgress.xpForNext > 0
        ? (profile.levelProgress.currentXp / profile.levelProgress.xpForNext)
            .clamp(0.0, 1.0)
        : 0.0;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Row
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isLight
                      ? AppColors.sakuraTrack
                      : theme.colorScheme.surfaceContainerHigh,
                  backgroundImage: profile.avatarUrl != null
                      ? CachedNetworkImageProvider(profile.avatarUrl!)
                      : null,
                  child: profile.avatarUrl == null
                      ? Icon(
                          LucideIcons.user,
                          size: 24,
                          color: isLight
                              ? AppColors.sakuraOn
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.5),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    Text(
                      profile.nickname,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (onEditNickname != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onEditNickname,
                        child: Icon(
                          LucideIcons.pencil,
                          size: 14,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isLight
                            ? AppColors.sakuraTrack
                            : theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        profile.jlptLevel,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isLight
                              ? AppColors.sakuraOn
                              : theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Level Progress
            Row(
              children: [
                Text(
                  'Lv.${profile.level}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: xpProgress,
                      minHeight: 6,
                      backgroundColor: isLight
                          ? AppColors.sakuraTrack
                          : theme.colorScheme.onSurface.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(
                        isLight ? AppColors.sakura : theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${profile.levelProgress.currentXp}/${profile.levelProgress.xpForNext} XP',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),

            Divider(
              height: 24,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            ),

            // Stats Row
            Row(
              children: stats.map((stat) {
                return Expanded(
                  child: Column(
                    children: [
                      Icon(stat.$1, size: 16, color: stat.$4),
                      const SizedBox(height: 2),
                      Text(
                        stat.$3,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        stat.$2,
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
