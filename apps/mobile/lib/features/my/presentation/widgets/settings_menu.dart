import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/auth/current_account_provider.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/providers/user_preferences_provider.dart';
import '../../../../core/services/haptic_service.dart';
import '../../providers/settings_sync_provider.dart';
import 'my_settings_group.dart';
import 'my_settings_toggle_tile.dart';

class SettingsMenu extends ConsumerWidget {
  const SettingsMenu({super.key});
  static const _jlptLevels = ['N5', 'N4', 'N3', 'N2', 'N1'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(userPreferencesProvider);
    final theme = Theme.of(context);

    return MySettingsGroup(
      label: '학습 설정',
      rows: [
        // JLPT Level
        ListTile(
          leading: const MySettingsIcon('jlpt', size: 20),
          title: const Text('JLPT 레벨', style: TextStyle(fontSize: 14)),
          trailing: Text(
            preferences.jlptLevel == 'ABSOLUTE_ZERO'
                ? '입문'
                : preferences.jlptLevel,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.5,
              letterSpacing: -0.35,
              color: theme.brightness == Brightness.light
                  ? const Color(0xFF767676)
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          onTap: () => _showJlptSheet(
            context,
            ref,
            preferences.jlptLevel,
          ),
        ),

        // Show Kana
        MySettingsToggleTile(
          leading: const MySettingsIcon('kana', size: 20),
          title: const Text('가나 학습 표시', style: TextStyle(fontSize: 14)),
          value: preferences.showKana,
          onChanged: (value) async {
            unawaited(HapticService().selection());
            try {
              await ref.read(settingsSyncServiceProvider).updateShowKana(value);
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
    );
  }

  Future<void> _showJlptSheet(
    BuildContext context,
    WidgetRef ref,
    String currentJlptLevel,
  ) async {
    final owner = ref.read(currentAccountIdProvider);
    bool accountCurrent() =>
        context.mounted &&
        owner != null &&
        ref.read(currentAccountIdProvider) == owner &&
        ref.read(currentAccountReaderProvider)() == owner;
    if (!accountCurrent()) return;
    final theme = Theme.of(context);
    final selection = await showModalBottomSheet<String>(
      context: context,
      shape: AppSizes.sheetShape,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
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
                      Navigator.pop(context, level);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (selection == null ||
        selection == currentJlptLevel ||
        !accountCurrent() ||
        ref.read(userPreferencesProvider).jlptLevel != currentJlptLevel) {
      return;
    }
    try {
      await ref.read(settingsSyncServiceProvider).updateJlptLevel(selection);
    } catch (_) {
      if (!context.mounted || !accountCurrent()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('JLPT 레벨 저장에 실패했습니다'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
