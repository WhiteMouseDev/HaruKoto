import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/theme/text_theme.dart';
import '../../data/models/profile_detail_model.dart';

class ProfileHero extends StatelessWidget {
  const ProfileHero({
    super.key,
    required this.profile,
    required this.summary,
    this.onEditNickname,
  });

  final ProfileInfo profile;
  final ProfileSummary summary;
  final VoidCallback? onEditNickname;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final foreground =
        light ? AppColors.redesignForeground : theme.colorScheme.onSurface;
    final muted = light
        ? AppColors.redesignMutedForeground
        : theme.colorScheme.onSurfaceVariant;
    final xp = profile.levelProgress;
    final nickname = profile.nickname.trim();
    final displayName = nickname.isEmpty
        ? '학습자님'
        : nickname.endsWith('님')
            ? nickname
            : '$nickname님';
    final xpProgress =
        xp.xpForNext > 0 ? (xp.currentXp / xp.xpForNext).clamp(0.0, 1.0) : 0.0;
    final xpTextStyle = TextStyle(
      fontFamily: redesignFontFamily,
      fontSize: 11,
      height: 1.4,
      letterSpacing: -0.275,
      color: muted,
    );
    final stats = [
      (
        'figma-my-calendar',
        '총 학습일',
        '${summary.totalStudyDays}일',
      ),
      (
        'figma-my-words',
        '학습 단어',
        '${summary.totalWordsStudied}개',
      ),
      (
        'figma-quiz-result-xp',
        '총 XP',
        '${profile.experiencePoints}',
      ),
      (
        'figma-my-streak',
        '최장 연속',
        '${profile.longestStreak}일',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: light
                ? AppColors.redesignSurface
                : theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 28),
                      child: Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  displayName,
                                  style: TextStyle(
                                    fontFamily: redesignFontFamily,
                                    fontSize: 18,
                                    height: 1.4,
                                    letterSpacing: -0.45,
                                    fontWeight: FontWeight.w600,
                                    color: foreground,
                                  ),
                                ),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(500),
                                    color: light
                                        ? AppColors.redesignVocabulary
                                        : theme.colorScheme
                                            .surfaceContainerHighest,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    child: Text(
                                      profile.jlptLevel == 'ABSOLUTE_ZERO'
                                          ? '입문'
                                          : profile.jlptLevel,
                                      style: TextStyle(
                                        fontFamily: redesignFontFamily,
                                        fontSize: 10,
                                        height: 1.4,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            light ? Colors.white : foreground,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (onEditNickname != null) const SizedBox(width: 44),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: xpProgress,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(500),
                      trackGap: 0,
                      backgroundColor: light
                          ? AppColors.redesignProgressTrack
                          : theme.colorScheme.surfaceContainer,
                      color: AppColors.brandPink,
                      semanticsLabel: '레벨 경험치',
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child:
                              Text('LV.${profile.level}', style: xpTextStyle),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          flex: 2,
                          child: Text(
                            '${xp.currentXp}/${xp.xpForNext} XP',
                            textAlign: TextAlign.end,
                            style: xpTextStyle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onEditNickname != null)
                Positioned(
                  top: 6,
                  right: 9,
                  width: 48,
                  height: 48,
                  child: IconButton(
                    tooltip: '닉네임 변경',
                    onPressed: onEditNickname,
                    padding: EdgeInsets.zero,
                    icon: Container(
                      width: 34,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: light
                              ? AppColors.redesignOutline
                              : theme.colorScheme.outline,
                        ),
                        borderRadius: BorderRadius.circular(500),
                      ),
                      child: Image.asset(
                        'assets/icons/figma-home-edit.png',
                        width: 16,
                        height: 16,
                        color: light ? null : muted,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  light ? AppColors.redesignOutline : theme.colorScheme.outline,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
            child: LayoutBuilder(builder: (context, constraints) {
              final columns = constraints.maxWidth < 280 ||
                      MediaQuery.textScalerOf(context).scale(14) > 21
                  ? 2
                  : 4;
              return Column(
                spacing: 12,
                children: [
                  for (var offset = 0; offset < stats.length; offset += columns)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final stat in stats.skip(offset).take(columns))
                          Expanded(
                            child: _ProfileMetric(
                              iconAsset: stat.$1,
                              label: stat.$2,
                              value: stat.$3,
                            ),
                          ),
                      ],
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({
    required this.iconAsset,
    required this.label,
    required this.value,
  });

  final String iconAsset;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    return Semantics(
      container: true,
      label: '$label $value',
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox.square(
            dimension: 20,
            child: Center(
              child: Image.asset(
                'assets/icons/$iconAsset.png',
                width: iconAsset == 'figma-quiz-result-xp' ? 11 : 18,
                height: iconAsset == 'figma-quiz-result-xp' ? 15 : 18,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: redesignFontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 1.4,
              letterSpacing: -0.4,
              color: light
                  ? AppColors.redesignForeground
                  : theme.colorScheme.onSurface,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: redesignFontFamily,
              fontSize: 11,
              height: 1.4,
              letterSpacing: -0.275,
              color: light
                  ? AppColors.redesignMutedForeground
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
