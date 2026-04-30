import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/providers/user_preferences_provider.dart';
import '../../../../core/services/haptic_service.dart';
import '../../providers/settings_sync_provider.dart';

class SettingsMenu extends ConsumerWidget {
  const SettingsMenu({super.key});
  static const _jlptLevels = ['N5', 'N4', 'N3', 'N2', 'N1'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final preferences = ref.watch(userPreferencesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            '학습 설정',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // JLPT Level
              ListTile(
                leading: const Icon(LucideIcons.graduationCap,
                    size: 20, color: AppColors.purple),
                title: const Text('JLPT 레벨', style: TextStyle(fontSize: 14)),
                trailing: Text(
                  preferences.jlptLevel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.purple,
                  ),
                ),
                onTap: () => _showJlptSheet(
                  context,
                  ref,
                  preferences.jlptLevel,
                ),
              ),
              const Divider(height: 1),

              // Show Kana
              SwitchListTile(
                secondary: const Icon(LucideIcons.languages,
                    size: 20, color: AppColors.sakura),
                title: const Text('가나 학습 표시', style: TextStyle(fontSize: 14)),
                value: preferences.showKana,
                onChanged: (value) async {
                  unawaited(HapticService().selection());
                  try {
                    await ref
                        .read(settingsSyncServiceProvider)
                        .updateShowKana(value);
                  } catch (_) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('가나 설정 저장에 실패했습니다'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showJlptSheet(
    BuildContext context,
    WidgetRef ref,
    String currentJlptLevel,
  ) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      shape: AppSizes.sheetShape,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'JLPT 레벨 선택',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                for (final level in _jlptLevels)
                  ListTile(
                    title: Text(level),
                    trailing: currentJlptLevel == level
                        ? const Icon(LucideIcons.check,
                            color: AppColors.purple, size: 20)
                        : null,
                    selected: currentJlptLevel == level,
                    selectedTileColor: theme.brightness == Brightness.light
                        ? AppColors.purpleTrack
                        : AppColors.purple.withValues(alpha: 0.18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onTap: () {
                      HapticService().selection();
                      Navigator.pop(context);
                      if (level != currentJlptLevel) {
                        unawaited(() async {
                          try {
                            await ref
                                .read(settingsSyncServiceProvider)
                                .updateJlptLevel(level);
                          } catch (_) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('JLPT 레벨 저장에 실패했습니다'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }());
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
