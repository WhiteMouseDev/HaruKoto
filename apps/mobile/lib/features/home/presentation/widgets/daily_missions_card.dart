import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../data/models/mission_model.dart';

class DailyMissionsCard extends StatelessWidget {
  final List<MissionModel> missions;

  const DailyMissionsCard({super.key, required this.missions});

  static IconData _missionIcon(String missionType) {
    final prefix = missionType.split('_').first;
    return switch (prefix) {
      'words' => LucideIcons.bookOpen,
      'quiz' => LucideIcons.target,
      'correct' => LucideIcons.sparkles,
      'chat' => LucideIcons.messageCircle,
      'kana' => LucideIcons.bookOpen,
      _ => LucideIcons.target,
    };
  }

  static _MissionVisualState _missionState(MissionModel mission) {
    if (mission.rewardClaimed || mission.isCompleted) {
      return _MissionVisualState.done;
    }
    if (mission.targetCount <= 0) {
      return _MissionVisualState.locked;
    }
    return _MissionVisualState.inProgress;
  }

  static Color _missionAccent(_MissionVisualState state) {
    return switch (state) {
      _MissionVisualState.done => AppColors.missionDoneFg,
      _MissionVisualState.inProgress => AppColors.missionInProgressFg,
      _MissionVisualState.locked => AppColors.missionLockedFg,
    };
  }

  static Color _missionContainer(_MissionVisualState state) {
    return switch (state) {
      _MissionVisualState.done => AppColors.missionDoneBg,
      _MissionVisualState.inProgress => AppColors.missionInProgressBg,
      _MissionVisualState.locked => AppColors.missionLockedBg,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completedCount = missions
        .where(
          (mission) =>
              DailyMissionsCard._missionState(mission) ==
              _MissionVisualState.done,
        )
        .length;
    final total = missions.length;
    final allCompleted = total > 0 && completedCount == total;

    // Sort: incomplete first, completed last
    final sorted = List<MissionModel>.from(missions)
      ..sort((a, b) {
        final aDone =
            DailyMissionsCard._missionState(a) == _MissionVisualState.done;
        final bDone =
            DailyMissionsCard._missionState(b) == _MissionVisualState.done;
        if (aDone == bDone) return 0;
        return aDone ? 1 : -1;
      });

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2)),
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
            if (allCompleted) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.missionDoneBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      LucideIcons.checkCircle,
                      size: 16,
                      color: AppColors.missionDoneFg,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '오늘의 미션을 모두 완료했어요!',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.missionDoneFg,
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

enum _MissionVisualState { done, inProgress, locked }

class _MissionItem extends StatelessWidget {
  final MissionModel mission;

  const _MissionItem({required this.mission});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final missionState = DailyMissionsCard._missionState(mission);
    final missionAccent = DailyMissionsCard._missionAccent(missionState);
    final missionContainer = DailyMissionsCard._missionContainer(missionState);
    final isDone = missionState == _MissionVisualState.done;
    final isLocked = missionState == _MissionVisualState.locked;

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
              color: missionContainer,
            ),
            child: Icon(
              isDone
                  ? LucideIcons.check
                  : isLocked
                      ? LucideIcons.lock
                      : DailyMissionsCard._missionIcon(mission.missionType),
              size: 18,
              color: missionAccent,
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
                color: isDone
                    ? AppColors.missionDoneFg.withValues(alpha: 0.78)
                    : isLocked
                        ? AppColors.missionLockedFg
                        : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                decoration: isDone ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Right
          if (isDone)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.zap, size: 14, color: missionAccent),
                const SizedBox(width: 2),
                Text(
                  '+${mission.xpReward}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: missionAccent,
                  ),
                ),
              ],
            )
          else if (isLocked)
            Icon(
              LucideIcons.lock,
              size: 16,
              color: missionAccent,
            )
          else
            Text(
              '${mission.currentCount}/${mission.targetCount}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: missionAccent,
              ),
            ),
        ],
      ),
    );
  }
}
