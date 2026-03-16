import 'package:flutter/material.dart';
import '../../../../core/constants/colors.dart';
import '../../data/models/mission_model.dart';

class DailyMissionsCard extends StatelessWidget {
  final List<MissionModel> missions;

  const DailyMissionsCard({super.key, required this.missions});

  static IconData _missionIcon(String missionType) {
    final prefix = missionType.split('_').first;
    return switch (prefix) {
      'words' => Icons.menu_book,
      'quiz' => Icons.gps_fixed,
      'correct' => Icons.auto_awesome,
      'chat' => Icons.chat_bubble_outline,
      'kana' => Icons.menu_book,
      _ => Icons.gps_fixed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completedCount = missions.where((m) => m.rewardClaimed).length;
    final total = missions.length;
    final allClaimed = total > 0 && completedCount == total;

    // Sort: incomplete first, completed last
    final sorted = List<MissionModel>.from(missions)
      ..sort((a, b) {
        if (a.rewardClaimed == b.rewardClaimed) return 0;
        return a.rewardClaimed ? 1 : -1;
      });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.lightBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '오늘의 미션',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '$completedCount/$total',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),

            // Completion banner
            if (allClaimed) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle,
                        size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      '오늘의 미션을 모두 완료했어요!',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Mission list
            Column(
              children: [
                for (int i = 0; i < sorted.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _MissionItem(mission: sorted[i]),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MissionItem extends StatelessWidget {
  final MissionModel mission;

  const _MissionItem({required this.mission});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          // Left circle
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: mission.rewardClaimed
                  ? theme.colorScheme.primary
                  : AppColors.lightSecondary,
            ),
            child: Icon(
              mission.rewardClaimed
                  ? Icons.check
                  : DailyMissionsCard._missionIcon(mission.missionType),
              size: 18,
              color: mission.rewardClaimed
                  ? Colors.white
                  : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),

          // Middle: label
          Expanded(
            child: Text(
              mission.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: mission.rewardClaimed
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                decoration:
                    mission.rewardClaimed ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Right
          if (mission.rewardClaimed)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bolt, size: 14, color: theme.colorScheme.primary),
                const SizedBox(width: 2),
                Text(
                  '+${mission.xpReward}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            )
          else
            Text(
              '${mission.currentCount}/${mission.targetCount}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
        ],
      ),
    );
  }
}
