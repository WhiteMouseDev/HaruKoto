import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../shared/widgets/app_skeleton.dart';
import '../../data/models/mission_model.dart';

class DailyMissionsCard extends StatelessWidget {
  const DailyMissionsCard({
    super.key,
    required this.missions,
    this.isLoading = false,
  });

  final List<MissionModel> missions;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ordered = [
      ...missions.where((mission) => !_isDone(mission)),
      ...missions.where(_isDone),
    ];

    return Padding(
      padding: AppSizes.pageHorizontalEdge,
      child: Column(
        children: [
          Text(
            '오늘의 미션',
            style: theme.textTheme.titleLarge?.copyWith(
              fontFamily: 'Pretendard',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              height: 1.4,
              letterSpacing: -0.5,
              color: _missionForeground(theme),
            ),
          ),
          const SizedBox(height: 16),
          if (isLoading)
            Semantics(
              label: '오늘의 미션을 불러오는 중',
              container: true,
              child: const Row(
                children: [
                  Expanded(child: _MissionPlaceholder()),
                  SizedBox(width: 8),
                  Expanded(child: _MissionPlaceholder()),
                  SizedBox(width: 8),
                  Expanded(child: _MissionPlaceholder()),
                ],
              ),
            ),
          for (var i = 0; i < ordered.length; i += 3) ...[
            if (i != 0) const SizedBox(height: 8),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var column = 0; column < 3; column++) ...[
                    if (column != 0) const SizedBox(width: 8),
                    Expanded(
                      child: i + column < ordered.length
                          ? _MissionTile(mission: ordered[i + column])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MissionPlaceholder extends StatelessWidget {
  const _MissionPlaceholder();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = MediaQuery.textScalerOf(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 143),
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 11),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.brightness == Brightness.light
              ? AppColors.redesignOutline
              : theme.colorScheme.outline,
        ),
      ),
      child: Column(
        children: [
          const AppSkeletonBlock(width: 64, height: 64, radius: 32),
          const SizedBox(height: 8),
          SizedBox(
            height: scale.scale(14) * 1.4,
            child: const Center(child: AppSkeletonBlock(width: 48, height: 11)),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: scale.scale(16) * 1.4,
            child: const Center(child: AppSkeletonBlock(width: 32, height: 13)),
          ),
        ],
      ),
    );
  }
}

bool _isDone(MissionModel mission) =>
    mission.rewardClaimed || mission.isCompleted;

Color _missionForeground(ThemeData theme) =>
    theme.brightness == Brightness.light
        ? const Color(0xFF111111)
        : theme.colorScheme.onSurface;

class _MissionTile extends StatelessWidget {
  const _MissionTile({required this.mission});

  final MissionModel mission;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final done = _isDone(mission);
    final locked = !done && mission.targetCount <= 0;
    final category = mission.missionType.split('_').first;
    final label = switch (category) {
      'correct' => '정답 달성',
      'kana' => '가나 학습',
      'quiz' => '퀴즈 풀이',
      'words' => '단어 학습',
      'chat' => 'AI 회화',
      _ => mission.label,
    };
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: 'Pretendard',
      fontSize: 14,
      height: 1.5,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.35,
      color: _missionForeground(theme),
    );
    final statusStyle = textStyle?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.4,
      letterSpacing: -0.4,
    );
    final pink = isLight ? AppColors.brandPink : AppColors.primaryContainer;
    final muted =
        isLight ? const Color(0xFF999999) : theme.colorScheme.onSurfaceVariant;

    return Semantics(
      container: true,
      label:
          '$label, ${done ? '완료' : locked ? '잠김' : '${mission.targetCount}개 중 ${mission.currentCount}개'}',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 143),
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 9),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isLight ? const Color(0xFFE5E5EC) : theme.colorScheme.outline,
            ),
          ),
          child: Column(
            children: [
              _MissionGlyph(category: category, locked: locked),
              const SizedBox(height: 8),
              Text(label, style: textStyle, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              if (done)
                Text('완료!', style: statusStyle?.copyWith(color: pink))
              else if (locked)
                Text('잠김', style: statusStyle?.copyWith(color: muted))
              else
                Text.rich(
                  TextSpan(
                    text: '${mission.currentCount}',
                    style: TextStyle(
                        color: mission.currentCount == 0 ? muted : pink),
                    children: [
                      TextSpan(
                        text: ' / ${mission.targetCount}',
                        style: TextStyle(color: _missionForeground(theme)),
                      ),
                    ],
                  ),
                  style: statusStyle,
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissionGlyph extends StatelessWidget {
  const _MissionGlyph({required this.category, required this.locked});

  final String category;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    const gray = Color(0xFFA5A5AF);
    const purple = Color(0xFF9C7BFE);

    final asset = switch (locked ? null : category) {
      'correct' => 'figma-home-mission-correct',
      'kana' => 'figma-home-mission-kana',
      'quiz' => 'figma-home-mission-quiz',
      _ => null,
    };
    if (asset != null) {
      return Image.asset(
        'assets/icons/$asset.png',
        width: 64,
        height: 64,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      );
    }

    final theme = Theme.of(context);
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.brightness == Brightness.light
            ? const Color(0xFFF7F7FB)
            : theme.colorScheme.surfaceContainerHigh,
      ),
      alignment: Alignment.center,
      child: locked
          ? const Icon(LucideIcons.lock, size: 24, color: gray)
          : switch (category) {
              'words' => Image.asset(
                  'assets/icons/figma-home-shortcut-words.png',
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
              'chat' =>
                const Icon(Icons.chat_bubble_rounded, size: 25, color: purple),
              _ => const Icon(LucideIcons.target, size: 24, color: purple),
            },
    );
  }
}
