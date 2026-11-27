import 'package:flutter/material.dart';

import '../../../../core/constants/colors.dart';
import '../../../../shared/widgets/app_skeleton.dart';
import 'my_settings_group.dart';
import 'profile_hero.dart';

class MyPageSkeleton extends StatelessWidget {
  const MyPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final light = colors.brightness == Brightness.light;
    final text = MediaQuery.textScalerOf(context);
    final metric = Column(
      children: [
        const AppSkeletonBlock(width: 20, height: 20, radius: 4),
        const SizedBox(height: 4),
        AppSkeletonBlock(width: 34, height: text.scale(14) * 1.5),
        AppSkeletonBlock(width: 49, height: text.scale(12) * 1.5),
      ],
    );
    return Semantics(
      label: '프로필 정보를 불러오는 중',
      liveRegion: true,
      excludeSemantics: true,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 40),
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: light
                  ? AppColors.redesignSurface
                  : colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          AppSkeletonBlock(
                            width: 94,
                            height: text.scale(18) * 1.4,
                          ),
                          const AppSkeletonBlock(width: 32, height: 21),
                        ],
                      ),
                    ),
                    const AppSkeletonBlock(width: 34, height: 28, radius: 20),
                  ],
                ),
                const SizedBox(height: 12),
                const AppSkeletonBlock(height: 6),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    AppSkeletonBlock(width: 32, height: text.scale(12) * 1.5),
                    AppSkeletonBlock(width: 72, height: text.scale(12) * 1.5),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ProfileMetricsCard(metrics: List.filled(4, metric)),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            color:
                light ? const Color(0xFFFEF0F2) : colors.surfaceContainerHigh,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: const ListTile(
              minTileHeight: 48,
              contentPadding: EdgeInsets.symmetric(horizontal: 16),
              minLeadingWidth: 20,
              horizontalTitleGap: 8,
              leading: AppSkeletonBlock(width: 18, height: 18, radius: 4),
              title: Align(
                alignment: Alignment.centerLeft,
                child: AppSkeletonBlock(width: 85, height: 16),
              ),
              trailing: AppSkeletonBlock(width: 7, height: 11, radius: 3),
            ),
          ),
          const SizedBox(height: 40),
          const MySettingsGroup(
            label: '학습 설정',
            rows: [
              _SettingPlaceholder(trailingWidth: 26),
              _SettingPlaceholder(trailingWidth: 48),
            ],
          ),
          const SizedBox(height: 40),
          const MySettingsGroup(
            label: '앱 설정',
            rows: [
              _SettingPlaceholder(trailingWidth: 62),
              _SettingPlaceholder(trailingWidth: 36),
            ],
          ),
        ],
      ),
    );
  }
}

class _SettingPlaceholder extends StatelessWidget {
  const _SettingPlaceholder({required this.trailingWidth});

  final double trailingWidth;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const SizedBox.square(
        dimension: 24,
        child: Center(
          child: AppSkeletonBlock(width: 20, height: 20, radius: 4),
        ),
      ),
      title: const Align(
        alignment: Alignment.centerLeft,
        child: AppSkeletonBlock(width: 84, height: 14),
      ),
      trailing: AppSkeletonBlock(width: trailingWidth, height: 16),
    );
  }
}
