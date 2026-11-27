import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/sizes.dart';
import '../../../../core/providers/device_settings_provider.dart';
import '../../../../core/providers/installed_app_version_provider.dart';
import '../../../../core/providers/notification_settings_provider.dart';
import '../../../../core/providers/quiz_settings_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/services/haptic_service.dart';
import '../../providers/settings_sync_provider.dart';
import 'my_settings_group.dart';
import 'my_settings_toggle_tile.dart';

class AppSettingsSection extends ConsumerWidget {
  const AppSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final light = theme.brightness == Brightness.light;
    final valueStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.5,
      letterSpacing: -0.35,
      color:
          light ? const Color(0xFF767676) : theme.colorScheme.onSurfaceVariant,
    );
    final themeMode = ref.watch(themeProvider);
    final deviceSettings = ref.watch(deviceSettingsProvider);
    final userPreferences = ref.watch(quizSettingsProvider);
    final version = ref.watch(installedAppVersionProvider).value;

    return MySettingsGroup(
      label: '앱 설정',
      rows: [
        ListTile(
          leading: const MySettingsIcon('app-version'),
          title: Row(
            children: [
              const Expanded(
                child: Text('앱 버전', style: TextStyle(fontSize: 14)),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: Text(
                  version ?? '—',
                  semanticsLabel: version ?? '앱 버전 정보 없음',
                  textAlign: TextAlign.end,
                  style: valueStyle,
                ),
              ),
            ],
          ),
        ),
        // Theme
        ListTile(
          leading: const MySettingsIcon('theme'),
          title: const Text('테마 선택', style: TextStyle(fontSize: 14)),
          trailing: Text(
            _themeModeLabel(themeMode),
            style: valueStyle,
          ),
          onTap: () => _showThemeSheet(context, ref, themeMode),
        ),

        // Furigana
        MySettingsToggleTile(
          leading: const MySettingsIcon('furigana'),
          title: const Text('읽기(후리가나) 표시', style: TextStyle(fontSize: 14)),
          subtitle: const Text('퀴즈에서 한자 위에 히라가나 표시'),
          value: userPreferences.showFurigana,
          onChanged: (value) async {
            unawaited(HapticService().selection());
            try {
              await ref
                  .read(settingsSyncServiceProvider)
                  .updateShowFurigana(value);
            } catch (_) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('후리가나 설정 저장에 실패했습니다'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          },
        ),

        // Sound Effects
        const _SoundToggle(),

        // Haptic Feedback
        const _HapticToggle(),

        // Study Reminder
        MySettingsToggleTile(
          leading: const MySettingsIcon('reminder'),
          title: const Text('학습 리마인더', style: TextStyle(fontSize: 14)),
          subtitle: const Text('매일 설정한 시간에 알림'),
          value: deviceSettings.reminderEnabled,
          onChanged: (value) {
            HapticService().selection();
            unawaited(
              ref
                  .read(notificationSettingsProvider.notifier)
                  .setReminderEnabled(value),
            );
          },
        ),
        if (deviceSettings.reminderEnabled) ...[
          ListTile(
            leading: const MySettingsIcon('reminder-time'),
            tileColor: light
                ? AppColors.redesignSurface
                : theme.colorScheme.surfaceContainerHigh,
            title: const Text('리마인더 시간', style: TextStyle(fontSize: 14)),
            trailing: Text(
              deviceSettings.reminderTimeLabel,
              style: valueStyle,
            ),
            onTap: () => _showTimePicker(context, ref),
          ),
        ],

        // Streak Defense
        MySettingsToggleTile(
          leading: const MySettingsIcon('streak-reminder'),
          title: const Text('연속학습 알림', style: TextStyle(fontSize: 14)),
          subtitle: const Text('매일 22:00에 학습 리마인더'),
          value: deviceSettings.streakDefenseEnabled,
          onChanged: (value) {
            HapticService().selection();
            unawaited(
              ref
                  .read(notificationSettingsProvider.notifier)
                  .setStreakDefenseEnabled(value),
            );
          },
        ),
      ],
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return '라이트';
      case ThemeMode.dark:
        return '다크';
      case ThemeMode.system:
        return '시스템';
    }
  }

  void _showTimePicker(BuildContext context, WidgetRef ref) async {
    final theme = Theme.of(context);
    final settings = ref.read(notificationSettingsProvider);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: settings.reminderHour, minute: settings.reminderMinute),
      builder: (context, child) {
        return Theme(
          data: theme.copyWith(
            timePickerTheme: TimePickerThemeData(
              // AM/PM 선택 상태를 명확하게
              dayPeriodColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.sakura;
                }
                return theme.colorScheme.surfaceContainerHigh;
              }),
              dayPeriodTextColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                return theme.colorScheme.onSurface.withValues(alpha: 0.6);
              }),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      unawaited(ref
          .read(notificationSettingsProvider.notifier)
          .setReminderTime(picked.hour, picked.minute));
    }
  }

  void _showThemeSheet(BuildContext context, WidgetRef ref, ThemeMode current) {
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
                    '테마 선택',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                for (final entry in [
                  (ThemeMode.light, '라이트', LucideIcons.sun),
                  (ThemeMode.dark, '다크', LucideIcons.moon),
                  (ThemeMode.system, '시스템', LucideIcons.smartphone),
                ])
                  ListTile(
                    leading: Icon(entry.$3, size: 20),
                    title: Text(entry.$2),
                    trailing: current == entry.$1
                        ? Icon(LucideIcons.check,
                            color: Theme.of(context).colorScheme.primary)
                        : null,
                    onTap: () {
                      unawaited(
                        ref
                            .read(deviceSettingsProvider.notifier)
                            .setThemeMode(entry.$1),
                      );
                      Navigator.pop(context);
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

class _SoundToggle extends ConsumerWidget {
  const _SoundToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(deviceSettingsProvider);
    return MySettingsToggleTile(
      leading: const MySettingsIcon('sound'),
      title: const Text('효과음', style: TextStyle(fontSize: 14)),
      subtitle: const Text('정답/오답 시 효과음 재생'),
      value: settings.soundEnabled,
      onChanged: (value) {
        HapticService().selection();
        unawaited(
          ref.read(deviceSettingsProvider.notifier).setSoundEnabled(value),
        );
      },
    );
  }
}

class _HapticToggle extends ConsumerWidget {
  const _HapticToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(deviceSettingsProvider);
    return MySettingsToggleTile(
      leading: const MySettingsIcon('vibration'),
      title: const Text('진동 피드백', style: TextStyle(fontSize: 14)),
      subtitle: const Text('터치 시 진동으로 반응'),
      value: settings.hapticEnabled,
      onChanged: (value) {
        // Fire haptic BEFORE disabling (so user feels the last toggle)
        HapticService().selection();
        unawaited(
          ref.read(deviceSettingsProvider.notifier).setHapticEnabled(value),
        );
      },
    );
  }
}
